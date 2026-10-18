"""Password hashing (PBKDF2) and login tokens (JWT)."""

import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone

import jwt

from .config import settings

PBKDF2_ITERATIONS = 200_000
JWT_ALGORITHM = "HS256"


def hash_password(password: str) -> str:
    """Stored as "pbkdf2_sha256$iterations$salt$hash". The plain password is never stored."""
    salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), bytes.fromhex(salt), PBKDF2_ITERATIONS)
    return f"pbkdf2_sha256${PBKDF2_ITERATIONS}${salt}${digest.hex()}"


def verify_password(password: str, stored: str | None) -> bool:
    if not stored:
        return False
    try:
        algorithm, iterations, salt, expected = stored.split("$")
        if algorithm != "pbkdf2_sha256":
            return False
        digest = hashlib.pbkdf2_hmac("sha256", password.encode(), bytes.fromhex(salt), int(iterations))
    except ValueError:
        return False
    return hmac.compare_digest(digest.hex(), expected)  # constant time compare


def token_lifetime_seconds() -> int:
    return settings.jwt_hours * 3600


def create_token(user_id: int, role: str) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "role": role,
        "iat": now,
        "exp": now + timedelta(seconds=token_lifetime_seconds()),
    }
    return jwt.encode(payload, settings.secret_jwt, algorithm=JWT_ALGORITHM)


def read_token(token: str) -> int | None:
    """The user id inside a valid token, or None if the token is wrong or expired."""
    try:
        payload = jwt.decode(token, settings.secret_jwt, algorithms=[JWT_ALGORITHM])
        return int(payload["sub"])
    except (jwt.PyJWTError, KeyError, ValueError):
        return None
