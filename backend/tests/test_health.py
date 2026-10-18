import tests  # noqa: F401  (test settings; must be the first import)
import unittest

from fastapi.testclient import TestClient

from app.main import create_app


class HealthTest(unittest.TestCase):
    def test_health(self):
        with TestClient(create_app(start_worker=False)) as client:
            response = client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "ok"})


if __name__ == "__main__":
    unittest.main()
