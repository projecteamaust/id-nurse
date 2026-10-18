import tests  # noqa: F401  (test settings; must be the first import)
import unittest
from datetime import date, datetime, timedelta

from sqlalchemy import select

from app import db
from app.models import AuditLog, DispenseCommand, Item, Order
from tests.helpers import ApiTestCase


def stock(item_id: int) -> int:
    with db.session_scope() as session:
        return session.get(Item, item_id).quantity


class CreateOrderTest(ApiTestCase):
    def test_create_order(self):
        order = self.create_order(self.nurse(), [(1, 3), (5, 2)])
        self.assertEqual(order["status"], "PENDING")
        self.assertEqual(order["patient"], {"file_number": "284913", "name": "Alex Morgan"})
        self.assertEqual(order["nurse"], {"employee_id": "48216", "name": "Maya Chen"})
        self.assertIsNone(order["approved_at"])
        self.assertIsNone(order["completed_at"])
        self.assertRegex(order["created_at"], r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d[+-]\d\d:\d\d$")
        self.assertEqual(order["items"][0], {"item_id": 1, "name": "Sterile gauze pads", "slot_number": 1,
                                             "cabinet_location": "A1", "qty_requested": 3, "qty_dispensed": 0})
        self.assertEqual(stock(1), 42, "stock must not change when the order is created")
        with db.session_scope() as session:
            entry = session.scalar(select(AuditLog).where(AuditLog.action == "order_created"))
            self.assertEqual(entry.summary, "Created order #1 for patient 284913 (2 items, 5 units)")

    def test_validation(self):
        nurse = self.nurse()

        def post(items, patient="284913"):
            body = {"patient_file_number": patient, "items": [{"item_id": i, "qty": q} for i, q in items]}
            return self.client.post("/orders", json=body, headers=nurse)

        self.assertEqual(post([]).json(), {"detail": "Order has no items"})
        for qty in (0, -1, 31):
            response = post([(1, qty)])
            self.assertEqual(response.status_code, 422)
            self.assertEqual(response.json()["detail"], "Quantity must be between 1 and 30")
        self.assertEqual(post([(1, 30)]).status_code, 201)
        self.assertEqual(post([(1, 1), (1, 2)]).status_code, 422)
        self.assertEqual(post([(1, 1)], patient="000000").status_code, 404)
        self.assertEqual(post([(99, 1)]).status_code, 409)
        not_enough = post([(4, 1)])  # the syringe drawer is empty
        self.assertEqual(not_enough.status_code, 409)
        self.assertEqual(not_enough.json()["detail"], "Not enough stock for 10 ml syringe")
        self.assertEqual(self.client.post("/orders", json={"items": []}, headers=nurse).status_code, 422)

    def test_needs_login(self):
        response = self.client.post("/orders", json={"patient_file_number": "284913", "items": []})
        self.assertEqual(response.status_code, 401)


class ApproveCancelTest(ApiTestCase):
    def test_approve_puts_a_command_in_the_arm_queue(self):
        nurse = self.nurse()
        order = self.create_order(nurse, [(5, 1), (1, 2)])
        approved = self.approve(nurse, order["id"])
        self.assertEqual(approved["status"], "DISPENSING")
        self.assertIsNotNone(approved["approved_at"])
        with db.session_scope() as session:
            command = session.scalar(select(DispenseCommand))
            self.assertEqual(command.status, "pending")
            # path is sorted by cabinet location: A1 (gauze) before B2 (gloves)
            self.assertEqual([stop.get("cabinet_location", stop["stop"]) for stop in command.path],
                             ["home", "A1", "B2", "pickup_window", "home"])

    def test_cancel(self):
        nurse = self.nurse()
        order = self.create_order(nurse, [(1, 1)])
        response = self.client.post(f"/orders/{order['id']}/cancel", headers=nurse)
        self.assertEqual(response.json()["status"], "CANCELLED")
        again = self.client.post(f"/orders/{order['id']}/approve", headers=nurse)
        self.assertEqual(again.status_code, 409)
        self.assertEqual(again.json()["detail"], "Order is CANCELLED, not PENDING")

    def test_only_pending_orders(self):
        nurse = self.nurse()
        order = self.create_order(nurse, [(1, 1)])
        self.approve(nurse, order["id"])
        self.assertEqual(self.client.post(f"/orders/{order['id']}/approve", headers=nurse).status_code, 409)
        self.assertEqual(self.client.post(f"/orders/{order['id']}/cancel", headers=nurse).status_code, 409)

    def test_a_nurse_can_only_touch_her_own_orders(self):
        order = self.create_order(self.nurse(), [(1, 1)])
        other = self.other_nurse()
        for path in (f"/orders/{order['id']}/approve", f"/orders/{order['id']}/cancel"):
            response = self.client.post(path, headers=other)
            self.assertEqual(response.status_code, 403)
            self.assertEqual(response.json()["detail"], "Not your order")
        self.assertEqual(self.client.get(f"/orders/{order['id']}", headers=other).status_code, 403)
        # a supervisor can do anything
        self.assertEqual(self.client.get(f"/orders/{order['id']}", headers=self.supervisor()).status_code, 200)
        self.approve(self.supervisor(), order["id"])

    def test_unknown_order(self):
        self.assertEqual(self.client.get("/orders/99", headers=self.nurse()).status_code, 404)
        self.assertEqual(self.client.post("/orders/99/approve", headers=self.nurse()).status_code, 404)


class ListOrdersTest(ApiTestCase):
    def test_list(self):
        nurse = self.nurse()
        self.create_order(nurse, [(1, 2), (3, 1)])
        self.create_order(nurse, [(5, 4)], patient="548220")
        orders = self.client.get("/orders", headers=nurse).json()
        self.assertEqual([o["id"] for o in orders], [2, 1])  # newest first
        self.assertEqual(orders[1], {"id": 1, "status": "PENDING", "patient_file_number": "284913",
                                     "nurse_name": "Maya Chen", "created_at": orders[1]["created_at"],
                                     "item_count": 2, "total_units": 3})
        self.assertEqual(len(self.client.get("/orders?limit=1", headers=nurse).json()), 1)

    def test_nurse_sees_only_her_own_supervisor_sees_all(self):
        self.create_order(self.nurse(), [(1, 1)])
        other = self.other_nurse()
        self.create_order(other, [(1, 1)])
        self.assertEqual([o["nurse_name"] for o in self.client.get("/orders", headers=other).json()], ["Omar Haddad"])
        # nurse_id is ignored for a nurse
        self.assertEqual(len(self.client.get("/orders?nurse_id=1", headers=other).json()), 1)
        boss = self.supervisor()
        self.assertEqual(len(self.client.get("/orders", headers=boss).json()), 2)
        self.assertEqual([o["nurse_name"] for o in self.client.get("/orders?nurse_id=1", headers=boss).json()],
                         ["Maya Chen"])
        self.assertEqual(len(self.client.get("/orders?status=CANCELLED", headers=boss).json()), 0)
        self.assertEqual(self.client.get("/orders?status=LOST", headers=boss).status_code, 422)

    def test_date_filters(self):
        nurse = self.nurse()
        self.create_order(nurse, [(1, 1)])
        self.create_order(nurse, [(1, 1)])
        # move order 1 to three days ago
        with db.session_scope() as session:
            old = session.get(Order, 1)
            old.created_at = old.created_at - timedelta(days=3)
            session.commit()
        today = date.today()
        earlier = (datetime.now() - timedelta(days=3)).date()

        def ids(**params):
            return [o["id"] for o in self.client.get("/orders", params=params, headers=nurse).json()]

        self.assertEqual(ids(**{"from": today.isoformat()}), [2])
        self.assertEqual(ids(to=earlier.isoformat()), [1])
        self.assertEqual(ids(**{"from": earlier.isoformat(), "to": today.isoformat()}), [2, 1])
        bad = self.client.get("/orders", params={"from": today.isoformat(), "to": earlier.isoformat()}, headers=nurse)
        self.assertEqual(bad.status_code, 422)
        self.assertEqual(bad.json()["detail"], "from must not be after to")
        self.assertEqual(self.client.get("/orders?from=yesterday", headers=nurse).status_code, 422)


if __name__ == "__main__":
    unittest.main()
