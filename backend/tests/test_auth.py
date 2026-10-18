import tests  # noqa: F401  (test settings; must be the first import)
import unittest

from sqlalchemy import select

from app import db
from app.models import AuditLog
from app.security import create_token, hash_password, verify_password
from tests.helpers import NURSE_ID, SUPERVISOR_ID, TEST_SUPERVISOR_PASSWORD, ApiTestCase


def audit_actions() -> list[str]:
    with db.session_scope() as session:
        return list(session.scalars(select(AuditLog.action).order_by(AuditLog.id)))


class PasswordTest(unittest.TestCase):
    def test_hash_and_verify(self):
        stored = hash_password("secret-1")
        self.assertNotIn("secret-1", stored)
        self.assertTrue(stored.startswith("pbkdf2_sha256$200000$"))
        self.assertTrue(verify_password("secret-1", stored))
        self.assertFalse(verify_password("secret-2", stored))
        self.assertFalse(verify_password("secret-1", None))
        self.assertFalse(verify_password("secret-1", "garbage"))

    def test_same_password_gets_different_hashes(self):
        self.assertNotEqual(hash_password("x"), hash_password("x"))


class LoginTest(ApiTestCase):
    def test_nurse_logs_in_with_id_only(self):
        response = self.client.post("/auth/login", json={"employee_id": NURSE_ID, "method": "scan"})
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["token_type"], "bearer")
        self.assertEqual(body["expires_in"], 8 * 3600)
        self.assertEqual(body["user"], {"id": 1, "employee_id": "48216", "name": "Maya Chen",
                                        "role": "nurse", "ward": "Ward 4 · Surgical"})
        self.assertEqual(audit_actions(), ["login_success"])

    def test_nurse_password_is_ignored(self):
        response = self.client.post("/auth/login",
                                    json={"employee_id": NURSE_ID, "method": "manual", "password": "anything"})
        self.assertEqual(response.status_code, 200)

    def test_unknown_id(self):
        response = self.client.post("/auth/login", json={"employee_id": "11111", "method": "manual"})
        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.json(), {"detail": "No staff ID found"})
        self.assertEqual(audit_actions(), ["login_failed"])

    def test_supervisor_needs_the_right_password(self):
        for password in (None, "wrong"):
            body = {"employee_id": SUPERVISOR_ID, "method": "manual"}
            if password:
                body["password"] = password
            response = self.client.post("/auth/login", json=body)
            self.assertEqual(response.status_code, 401)
            self.assertEqual(response.json()["detail"], "Wrong password")
        ok = self.client.post("/auth/login", json={"employee_id": SUPERVISOR_ID, "method": "manual",
                                                   "password": TEST_SUPERVISOR_PASSWORD})
        self.assertEqual(ok.status_code, 200)
        self.assertEqual(ok.json()["user"]["role"], "supervisor")
        self.assertEqual(audit_actions(), ["login_failed", "login_failed", "login_success"])

    def test_bad_method(self):
        response = self.client.post("/auth/login", json={"employee_id": NURSE_ID, "method": "telepathy"})
        self.assertEqual(response.status_code, 422)
        self.assertIsInstance(response.json()["detail"], str)

    def test_me(self):
        response = self.client.get("/me", headers=self.nurse())
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["employee_id"], NURSE_ID)

    def test_me_without_or_with_a_bad_token(self):
        self.assertEqual(self.client.get("/me").status_code, 401)
        self.assertEqual(self.client.get("/me").json(), {"detail": "Not signed in"})
        bad = self.client.get("/me", headers={"Authorization": "Bearer not-a-token"})
        self.assertEqual(bad.status_code, 401)
        unknown_user = self.client.get("/me", headers={"Authorization": f"Bearer {create_token(999, 'nurse')}"})
        self.assertEqual(unknown_user.status_code, 401)

    def test_users_list_is_for_supervisors(self):
        self.assertEqual(self.client.get("/users", headers=self.nurse()).status_code, 403)
        response = self.client.get("/users", headers=self.supervisor())
        self.assertEqual([u["name"] for u in response.json()], ["Elena Ruiz", "Maya Chen"])
        nurses = self.client.get("/users?role=nurse", headers=self.supervisor()).json()
        self.assertEqual([u["employee_id"] for u in nurses], [NURSE_ID])
        self.assertEqual(self.client.get("/users?role=chef", headers=self.supervisor()).status_code, 422)


if __name__ == "__main__":
    unittest.main()
