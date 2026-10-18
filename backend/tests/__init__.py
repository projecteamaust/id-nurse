"""Test settings: set before any app module is imported, so tests never need a .env file."""

import os

os.environ["SECRET_JWT"] = "test-secret-only-for-unit-tests-0123456789"
os.environ["DATABASE_URL"] = "sqlite://"
os.environ["ARM_MODE"] = "mock"
os.environ["ARM_SIM_STEP_SECONDS"] = "0"
os.environ["MAX_QTY_PER_ITEM"] = "30"
os.environ["JWT_HOURS"] = "8"
