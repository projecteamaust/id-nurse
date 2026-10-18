import tests  # noqa: F401  (test settings; must be the first import)
import unittest
from datetime import date
from unittest import mock

from sqlalchemy import select

from app import db
from app.models import AuditLog
from tests.helpers import ApiTestCase


class PatientTest(ApiTestCase):
    def test_get_patient(self):
        with mock.patch("app.services.date") as fake_date:
            fake_date.today.return_value = date(2026, 10, 18)
            response = self.client.get("/patients/284913", headers=self.nurse())
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"id": 1, "file_number": "284913", "name": "Alex Morgan", "age": 34,
                                           "room": "2B-12", "diagnosis_code": "T81.4"})

    def test_age_before_birthday(self):
        with mock.patch("app.services.date") as fake_date:
            fake_date.today.return_value = date(2026, 3, 13)  # one day before the 34th birthday
            response = self.client.get("/patients/284913", headers=self.nurse())
        self.assertEqual(response.json()["age"], 33)

    def test_unknown_patient(self):
        response = self.client.get("/patients/000000", headers=self.nurse())
        self.assertEqual(response.status_code, 404)
        self.assertEqual(response.json(), {"detail": "No patient with this file number"})

    def test_needs_login(self):
        self.assertEqual(self.client.get("/patients/284913").status_code, 401)


class ItemsTest(ApiTestCase):
    def test_list_items(self):
        items = self.client.get("/items", headers=self.nurse()).json()
        self.assertEqual(len(items), 6)
        self.assertEqual(items[0], {"id": 1, "name": "Sterile gauze pads", "sku": "WC-001", "category": "Wound care",
                                    "slot_number": 1, "cabinet_location": "A1", "quantity": 42, "min_quantity": 10,
                                    "low_stock": False})
        self.assertTrue(items[1]["low_stock"])  # 9 <= 10

    def test_filters(self):
        wound = self.client.get("/items", params={"category": "Wound care"}, headers=self.nurse()).json()
        self.assertEqual([i["sku"] for i in wound], ["WC-001", "WC-002"])
        gauze = self.client.get("/items", params={"search": "GAUZE"}, headers=self.nurse()).json()
        self.assertEqual([i["name"] for i in gauze], ["Sterile gauze pads"])
        percent = self.client.get("/items", params={"search": "%"}, headers=self.nurse()).json()
        self.assertEqual(percent, [])

    def test_supervisor_edits_stock(self):
        response = self.client.patch("/items/4", json={"quantity": 40}, headers=self.supervisor())
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["quantity"], 40)
        self.assertFalse(response.json()["low_stock"])
        with db.session_scope() as session:
            entry = session.scalar(select(AuditLog).where(AuditLog.action == "stock_edit"))
            self.assertEqual(entry.details, {"item_id": 4, "old_quantity": 0, "new_quantity": 40})
            self.assertEqual(entry.summary, "Set 10 ml syringe to 40 units (was 0)")

    def test_stock_edit_rules(self):
        self.assertEqual(self.client.patch("/items/4", json={"quantity": 5}, headers=self.nurse()).status_code, 403)
        for bad in (-1, 1000):
            response = self.client.patch("/items/4", json={"quantity": bad}, headers=self.supervisor())
            self.assertEqual(response.status_code, 422)
            self.assertEqual(response.json()["detail"], "Quantity must be between 0 and 999")
        self.assertEqual(self.client.patch("/items/4", json={"quantity": "lots"},
                                           headers=self.supervisor()).status_code, 422)
        self.assertEqual(self.client.patch("/items/99", json={"quantity": 5},
                                           headers=self.supervisor()).status_code, 404)

    def test_low_stock_report(self):
        self.assertEqual(self.client.get("/reports/low-stock", headers=self.nurse()).status_code, 403)
        low = self.client.get("/reports/low-stock", headers=self.supervisor()).json()
        self.assertEqual([(i["name"], i["quantity"], i["qty_to_minimum"]) for i in low],
                         [("10 ml syringe", 0, 10), ("Adhesive dressing", 9, 1)])

    def test_low_stock_at_exactly_the_minimum(self):
        self.client.patch("/items/1", json={"quantity": 10}, headers=self.supervisor())
        low = self.client.get("/reports/low-stock", headers=self.supervisor()).json()
        gauze = next(i for i in low if i["id"] == 1)
        self.assertEqual(gauze["qty_to_minimum"], 0)


if __name__ == "__main__":
    unittest.main()
