"""Supervisor dashboard: audit log, dispense CSV and problem reports."""

import tests  # noqa: F401  (test settings; must be the first import)
import csv
import io
import unittest

from app.arm import SimulatedArm
from app.services import DISPENSE_CSV_COLUMNS
from tests.helpers import ApiTestCase


class AuditTest(ApiTestCase):
    def test_audit_log(self):
        nurse = self.nurse()
        order = self.create_order(nurse, [(1, 1)])
        self.approve(nurse, order["id"])
        self.run_arm()
        boss = self.supervisor()
        self.assertEqual(self.client.get("/audit", headers=nurse).status_code, 403)

        entries = self.client.get("/audit", headers=boss).json()
        self.assertEqual([e["action"] for e in entries],
                         ["login_success", "order_finished", "pick_ok", "order_approved", "order_created",
                          "login_success"])
        finished = entries[1]
        self.assertIsNone(finished["actor"], "the robot's actions have no actor")
        self.assertEqual(finished["order_id"], order["id"])
        self.assertEqual(finished["summary"], "Order #1 finished: DONE (1 of 1 units)")
        self.assertEqual(entries[-1]["actor"], {"employee_id": "48216", "name": "Maya Chen"})
        self.assertIsNone(entries[0]["order_id"])
        self.assertNotIn("details", entries[0])

        mine = self.client.get("/audit?nurse_id=1", headers=boss).json()
        self.assertTrue(all(e["actor"]["employee_id"] == "48216" for e in mine))
        self.assertEqual(len(self.client.get("/audit?limit=2", headers=boss).json()), 2)
        self.assertEqual(self.client.get("/audit?from=2026-10-10&to=2026-10-01", headers=boss).status_code, 422)


class DispenseCsvTest(ApiTestCase):
    def test_csv(self):
        nurse = self.nurse()
        done = self.create_order(nurse, [(1, 2), (5, 1)])
        self.approve(nurse, done["id"])
        cancelled = self.create_order(nurse, [(3, 1)])
        self.client.post(f"/orders/{cancelled['id']}/cancel", headers=nurse)
        self.create_order(nurse, [(6, 1)])  # still PENDING: included, completed_at empty
        self.run_arm()
        self.assertEqual(self.client.get("/reports/dispense.csv", headers=nurse).status_code, 403)

        response = self.client.get("/reports/dispense.csv", headers=self.supervisor())
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.headers["content-type"], "text/csv; charset=utf-8")
        self.assertIn('filename="dispense-report.csv"', response.headers["content-disposition"])
        rows = list(csv.reader(io.StringIO(response.text)))
        self.assertEqual(rows[0], DISPENSE_CSV_COLUMNS)
        self.assertEqual([(r[0], r[3], r[7], r[9], r[10]) for r in rows[1:]],
                         [("1", "DONE", "Sterile gauze pads", "2", "2"),
                          ("1", "DONE", "Nitrile gloves, M", "1", "1"),
                          ("3", "PENDING", "Procedure mask", "1", "0")])
        self.assertEqual(rows[3][2], "", "completed_at is empty while the order is not finished")
        self.assertIn('"Nitrile gloves, M"', response.text, "text with a comma is quoted")
        self.assertEqual(rows[1][5:7], ["48216", "Maya Chen"])


class ProblemReportTest(ApiTestCase):
    def partial_order(self, nurse: dict) -> dict:
        order = self.create_order(nurse, [(1, 1), (2, 2)])
        self.approve(nurse, order["id"])
        arm = SimulatedArm(step_seconds=0)
        arm.fail_slots = {2}
        self.run_arm(arm)
        return order

    def test_report_and_resolve(self):
        nurse = self.nurse()
        order = self.partial_order(nurse)
        response = self.client.post(f"/orders/{order['id']}/report", json={"note": "  Drawer 2 looked jammed "},
                                    headers=nurse)
        self.assertEqual(response.status_code, 201, response.text)
        report = response.json()
        self.assertEqual(report["status"], "open")
        self.assertEqual(report["note"], "Drawer 2 looked jammed")
        self.assertEqual(report["nurse"], {"employee_id": "48216", "name": "Maya Chen"})
        self.assertEqual(report["missing_items"],
                         [{"item_id": 2, "name": "Adhesive dressing", "slot_number": 2, "qty_missing": 2}])
        self.assertIsNone(report["resolved_at"])

        again = self.client.post(f"/orders/{order['id']}/report", json={}, headers=nurse)
        self.assertEqual(again.status_code, 409)
        self.assertEqual(again.json()["detail"], "This order already has an open report")

        boss = self.supervisor()
        self.assertEqual(self.client.get("/problem-reports", headers=nurse).status_code, 403)
        self.assertEqual([r["id"] for r in self.client.get("/problem-reports", headers=boss).json()], [report["id"]])

        resolved = self.client.post(f"/problem-reports/{report['id']}/resolve", headers=boss)
        self.assertEqual(resolved.status_code, 200)
        self.assertEqual(resolved.json()["status"], "resolved")
        self.assertEqual(resolved.json()["resolved_by"], {"employee_id": "31082", "name": "Elena Ruiz"})
        self.assertIsNotNone(resolved.json()["resolved_at"])
        twice = self.client.post(f"/problem-reports/{report['id']}/resolve", headers=boss)
        self.assertEqual(twice.status_code, 409)
        self.assertEqual(twice.json()["detail"], "Report is already resolved")

        self.assertEqual(self.client.get("/problem-reports", headers=boss).json(), [])
        self.assertEqual(len(self.client.get("/problem-reports?status=resolved", headers=boss).json()), 1)
        self.assertEqual(len(self.client.get("/problem-reports?status=all", headers=boss).json()), 1)

        # After it is resolved, a new report on the same order is allowed (no body at all is fine too).
        self.assertEqual(self.client.post(f"/orders/{order['id']}/report", headers=nurse).status_code, 201)

    def test_report_rules(self):
        nurse = self.nurse()
        order = self.partial_order(nurse)
        too_long = self.client.post(f"/orders/{order['id']}/report", json={"note": "x" * 201}, headers=nurse)
        self.assertEqual(too_long.status_code, 422)
        self.assertEqual(self.client.post(f"/orders/{order['id']}/report", headers=self.other_nurse()).status_code,
                         403)
        done = self.create_order(nurse, [(1, 1)])
        self.approve(nurse, done["id"])
        self.run_arm()
        not_partial = self.client.post(f"/orders/{done['id']}/report", json={}, headers=nurse)
        self.assertEqual(not_partial.status_code, 409)
        self.assertEqual(self.client.post("/problem-reports/999/resolve", headers=self.supervisor()).status_code, 404)
        empty_note = self.client.post(f"/orders/{order['id']}/report", json={"note": ""}, headers=nurse)
        self.assertIsNone(empty_note.json()["note"])


if __name__ == "__main__":
    unittest.main()
