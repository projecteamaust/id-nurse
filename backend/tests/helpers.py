"""Shared test setup: a fresh in-memory database with the demo data for every test."""

import unittest

from fastapi.testclient import TestClient

from app import db
from app.seed import seed

# Only used inside the tests' throw-away in-memory database.
TEST_SUPERVISOR_PASSWORD = "test-only-password"
NURSE_ID = "48216"
SUPERVISOR_ID = "31082"
OTHER_NURSE_ID = "50017"


def fresh_database(url: str = "sqlite://") -> None:
    db.configure(url)
    db.create_tables()
    with db.session_scope() as session:
        seed(session, TEST_SUPERVISOR_PASSWORD)


class ApiTestCase(unittest.TestCase):
    """A test with a fresh database and an API client (the arm worker is not started)."""

    def setUp(self):
        from app.main import create_app

        fresh_database()
        self.client = TestClient(create_app(start_worker=False))

    def tearDown(self):
        self.client.close()

    def login(self, employee_id: str = NURSE_ID, password: str | None = None) -> dict:
        body = {"employee_id": employee_id, "method": "manual"}
        if password is not None:
            body["password"] = password
        response = self.client.post("/auth/login", json=body)
        self.assertEqual(response.status_code, 200, response.text)
        return {"Authorization": f"Bearer {response.json()['access_token']}"}

    def nurse(self) -> dict:
        return self.login(NURSE_ID)

    def supervisor(self) -> dict:
        return self.login(SUPERVISOR_ID, TEST_SUPERVISOR_PASSWORD)

    def other_nurse(self) -> dict:
        """Signs in a second nurse (added on first use), for the "not your order" checks."""
        from app.models import User

        with db.session_scope() as session:
            if session.query(User).filter_by(employee_id=OTHER_NURSE_ID).first() is None:
                session.add(User(employee_id=OTHER_NURSE_ID, name="Omar Haddad", role="nurse", ward="Ward 2"))
                session.commit()
        return self.login(OTHER_NURSE_ID)

    def create_order(self, headers: dict, items: list[tuple[int, int]], patient: str = "284913") -> dict:
        body = {"patient_file_number": patient, "items": [{"item_id": i, "qty": q} for i, q in items]}
        response = self.client.post("/orders", json=body, headers=headers)
        self.assertEqual(response.status_code, 201, response.text)
        return response.json()

    def approve(self, headers: dict, order_id: int) -> dict:
        response = self.client.post(f"/orders/{order_id}/approve", headers=headers)
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()

    def run_arm(self, arm=None) -> "SimulatedArm":
        """Lets the arm worker dispense everything in the queue, right now, on this thread."""
        from app.arm import SimulatedArm
        from app.worker import ArmWorker

        arm = arm or SimulatedArm(step_seconds=0)
        worker = ArmWorker(arm)
        while worker.run_once():
            pass
        return arm
