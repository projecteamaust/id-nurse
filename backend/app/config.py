"""All settings, read from environment variables (or backend/.env).

Nothing secret is written in the code: the JWT secret and the database password come from .env.
Real environment variables win over values in .env.
"""

import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv

BACKEND_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BACKEND_DIR / ".env")

ARM_MODES = ("mock", "real")


class ConfigError(RuntimeError):
    """A setting is missing or has a wrong value."""


@dataclass(frozen=True)
class Settings:
    database_url: str
    secret_jwt: str
    jwt_hours: int
    max_qty_per_item: int
    arm_mode: str
    serial_port: str
    arm_sim_step_seconds: float


def _int(name: str, default: int) -> int:
    value = os.environ.get(name, "").strip()
    if not value:
        return default
    try:
        return int(value)
    except ValueError:
        raise ConfigError(f"{name} must be a whole number, got {value!r}") from None


def _float(name: str, default: float) -> float:
    value = os.environ.get(name, "").strip()
    if not value:
        return default
    try:
        return float(value)
    except ValueError:
        raise ConfigError(f"{name} must be a number, got {value!r}") from None


def _database_url() -> str:
    url = os.environ.get("DATABASE_URL", "").strip() or "sqlite:///id_nurse.db"
    # A relative SQLite path is taken from the backend/ folder, not from where the command runs.
    prefix = "sqlite:///"
    if url.startswith(prefix) and url != "sqlite://" and not url.startswith(prefix + "/"):
        path = Path(url[len(prefix):])
        if not path.is_absolute():
            url = prefix + (BACKEND_DIR / path).as_posix()
    return url


def load_settings() -> Settings:
    secret = os.environ.get("SECRET_JWT", "").strip()
    if not secret:
        raise ConfigError("SECRET_JWT is not set. Copy backend/.env.example to backend/.env and set it.")
    if secret == "change-me":
        raise ConfigError("SECRET_JWT still has the example value. Set your own random value in backend/.env.")
    arm_mode = os.environ.get("ARM_MODE", "mock").strip().lower() or "mock"
    if arm_mode not in ARM_MODES:
        raise ConfigError(f"ARM_MODE must be one of {ARM_MODES}, got {arm_mode!r}")
    return Settings(
        database_url=_database_url(),
        secret_jwt=secret,
        jwt_hours=_int("JWT_HOURS", 8),
        max_qty_per_item=_int("MAX_QTY_PER_ITEM", 30),
        arm_mode=arm_mode,
        serial_port=os.environ.get("SERIAL_PORT", "COM3").strip(),
        arm_sim_step_seconds=_float("ARM_SIM_STEP_SECONDS", 0.25),
    )


settings = load_settings()
