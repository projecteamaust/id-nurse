"""The full cycle: approve -> arm worker picks each unit -> delivery -> DONE / PARTIAL / FAILED."""

import tests  # noqa: F401  (test settings; must be the first import)
import os
import tempfile
import time
import unittest

from fastapi.testclient import TestClient
from sqlalchemy import select

from app import db
from app.arm import SimulatedArm
from app.models import AuditLog, DispenseCommand, Item
from app.worker import ArmWorker
from tests.helpers import ApiTestCase, fresh_database


def stock(item_id: int) -> int:
    with db.session_scope() as session:
        return session.get(Item, item_id).quantity


def actions(order_id: int) -> list[str]:
    with db.session_scope() as session:
        return list(session.scalars(select(AuditLog.action).where(AuditLog.order_id == order_id)
                                    .order_by(AuditLog.id)))


def command_status(order_id: int) -> str:
    with db.session_scope() as session:
        return session.scalar(select(DispenseCommand.status).where(DispenseCommand.order_id == order_id))


class DispensingTest(ApiTestCase):
    def test_full_cycle_done(self):
        nurse = self.nurse()
        order = self.create_order(nurse, [(5, 1), (1, 2)])
        self.approve(nurse, order["id"])
        self.assertEqual(stock(1), 42, "stock must not change at approval")

        arm = self.run_arm()

        result = self.client.get(f"/orders/{order['id']}", headers=nurse).json()
        self.assertEqual(result["status"], "DONE")
        self.assertIsNotNone(result["completed_at"])
        self.assertEqual([(i["item_id"], i["qty_dispensed"]) for i in result["items"]], [(5, 1), (1, 2)])
        self.assertEqual((stock(1), stock(5)), (40, 63))
        self.assertEqual(command_status(order["id"]), "completed")
        self.assertEqual(actions(order["id"]),
                         ["order_created", "order_approved", "pick_ok", "pick_ok", "pick_ok", "order_finished"])
        # The arm follows the cabinet location: A1 twice, then B2, then the pickup window.
        drawer_visits = [m for m in arm.moves if m.startswith("grab_")]
        self.assertEqual(drawer_visits, ["grab_slot1", "grab_slot1", "grab_slot5"])
        self.assertEqual(arm.moves[0], "home")
        self.assertEqual(arm.moves[-2:], ["window", "home"])

    def test_empty_drawer_is_retried_once_then_partial(self):
        nurse = self.nurse()
        order = self.create_order(nurse, [(1, 1), (2, 2)])
        self.approve(nurse, order["id"])
        # Someone takes the last stock out of drawer 2 after the order was made.
        self.client.patch("/items/2", json={"quantity": 0}, headers=self.supervisor())

        self.run_arm()

        result = self.client.get(f"/orders/{order['id']}", headers=nurse).json()
        self.assertEqual(result["status"], "PARTIAL")
        self.assertEqual([i["qty_dispensed"] for i in result["items"]], [1, 0])
        self.assertEqual(actions(order["id"]),
                         ["order_created", "order_approved", "pick_ok", "pick_failed", "pick_failed",
                          "order_finished"])
        self.assertEqual(stock(1), 41)
        self.assertEqual(stock(2), 0)
        self.assertEqual(command_status(order["id"]), "completed")  # a box was delivered

    def test_arm_fault_from_the_start_is_failed(self):
        nurse = self.nurse()
        order = self.create_order(nurse, [(1, 2)])
        self.approve(nurse, order["id"])
        arm = SimulatedArm(step_seconds=0)
        arm.fail_after_picks = 0

        self.run_arm(arm)

        result = self.client.get(f"/orders/{order['id']}", headers=nurse).json()
        self.assertEqual(result["status"], "FAILED")
        self.assertEqual(stock(1), 42, "nothing was picked, so stock is unchanged")
        self.assertEqual(command_status(order["id"]), "failed")
        self.assertNotIn("window", arm.moves, "an empty box is not delivered")
        self.assertEqual(actions(order["id"]).count("pick_failed"), 2)

    def test_retry_succeeds(self):
        nurse = self.nurse()
        order = self.create_order(nurse, [(1, 2)])
        self.approve(nurse, order["id"])

        class FlakyArm(SimulatedArm):
            """Fails only the very first pick."""

            def pick(self, slot_number):
                if not getattr(self, "failed_once", False):
                    self.failed_once = True
                    self.fail_slots = {slot_number}
                    try:
                        return super().pick(slot_number)
                    finally:
                        self.fail_slots = set()
                return super().pick(slot_number)

        self.run_arm(FlakyArm(step_seconds=0))
        result = self.client.get(f"/orders/{order['id']}", headers=nurse).json()
        self.assertEqual(result["status"], "DONE")
        self.assertEqual(actions(order["id"]).count("pick_failed"), 1)

    def test_fault_after_some_picks_is_partial(self):
        nurse = self.nurse()
        order = self.create_order(nurse, [(1, 3)])
        self.approve(nurse, order["id"])
        arm = SimulatedArm(step_seconds=0)
        arm.fail_after_picks = 1
        self.run_arm(arm)
        result = self.client.get(f"/orders/{order['id']}", headers=nurse).json()
        self.assertEqual(result["status"], "PARTIAL")
        self.assertEqual(result["items"][0]["qty_dispensed"], 1)
        self.assertEqual(stock(1), 41)

    def test_delivery_fault_is_failed(self):
        nurse = self.nurse()
        order = self.create_order(nurse, [(1, 1)])
        self.approve(nurse, order["id"])

        class StuckWindow(SimulatedArm):
            def deliver(self):
                from app.arm import ArmError

                raise ArmError("window jammed")

        self.run_arm(StuckWindow(step_seconds=0))
        self.assertEqual(self.client.get(f"/orders/{order['id']}", headers=nurse).json()["status"], "FAILED")
        with db.session_scope() as session:
            command = session.scalar(select(DispenseCommand))
            self.assertEqual(command.status, "failed")
            self.assertIn("window jammed", command.error)

    def test_orders_are_dispensed_one_at_a_time_oldest_first(self):
        nurse = self.nurse()
        first = self.create_order(nurse, [(6, 1)])
        second = self.create_order(nurse, [(1, 1)])
        self.approve(nurse, second["id"])
        self.approve(nurse, first["id"])
        arm = self.run_arm()
        # second was approved first, so it is picked first
        self.assertEqual([m for m in arm.moves if m.startswith("grab_")], ["grab_slot1", "grab_slot6"])

    def test_restart_continues_an_interrupted_command(self):
        from app import services

        nurse = self.nurse()
        order = self.create_order(nurse, [(1, 2)])
        self.approve(nurse, order["id"])
        # The server stops after the first pick.
        with db.session_scope() as session:
            job = services.claim_next_command(session)
            services.record_pick_ok(session, job.order_id, job.picks[0])
        with db.session_scope() as session:
            self.assertEqual(services.recover_interrupted_commands(session), 1)
        arm = self.run_arm()
        result = self.client.get(f"/orders/{order['id']}", headers=nurse).json()
        self.assertEqual(result["status"], "DONE")
        self.assertEqual(stock(1), 40)
        self.assertEqual([m for m in arm.moves if m.startswith("grab_")], ["grab_slot1"], "only the unit still missing")

    def test_queue_empty(self):
        self.assertFalse(ArmWorker(SimulatedArm(step_seconds=0)).run_once())


class WorkerThreadTest(unittest.TestCase):
    """The real background thread, with a SQLite file (like the local demo)."""

    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        fresh_database("sqlite:///" + os.path.join(self.folder.name, "test.db").replace("\\", "/"))

    def tearDown(self):
        db.get_engine().dispose()
        self.folder.cleanup()

    def test_server_dispenses_in_the_background(self):
        from app.main import create_app
        from tests.helpers import NURSE_ID

        with TestClient(create_app(start_worker=True)) as client:
            token = client.post("/auth/login", json={"employee_id": NURSE_ID, "method": "scan"}).json()["access_token"]
            headers = {"Authorization": f"Bearer {token}"}
            body = {"patient_file_number": "284913", "items": [{"item_id": 1, "qty": 2}]}
            order_id = client.post("/orders", json=body, headers=headers).json()["id"]
            client.post(f"/orders/{order_id}/approve", headers=headers)
            status = "DISPENSING"
            deadline = time.time() + 10
            while status == "DISPENSING" and time.time() < deadline:  # poll like the Prepare screen
                time.sleep(0.1)
                status = client.get(f"/orders/{order_id}", headers=headers).json()["status"]
        self.assertEqual(status, "DONE")


if __name__ == "__main__":
    unittest.main()
