"""Database connection (SQLAlchemy).

The same code runs on PostgreSQL (the real database) and SQLite (tests and the local demo).
The database is chosen only by DATABASE_URL in .env.
"""

from contextlib import contextmanager
from datetime import datetime, timezone

from sqlalchemy import DateTime, Engine, create_engine, event
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker
from sqlalchemy.pool import StaticPool
from sqlalchemy.types import TypeDecorator

from .config import settings


class Base(DeclarativeBase):
    pass


class UTCDateTime(TypeDecorator):
    """A date and time that is always stored in UTC.

    PostgreSQL keeps the timezone (TIMESTAMPTZ); SQLite does not, so we store UTC there too
    and add the UTC zone back when reading. The API turns it into server local time.
    """

    impl = DateTime(timezone=True)
    cache_ok = True

    def process_bind_param(self, value, dialect):
        if value is None:
            return None
        if value.tzinfo is None:
            raise ValueError("Dates must have a timezone")
        value = value.astimezone(timezone.utc)
        return value.replace(tzinfo=None) if dialect.name == "sqlite" else value

    def process_result_value(self, value, dialect):
        if value is not None and value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        return value


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


_engine: Engine | None = None
_session_factory: sessionmaker | None = None


def configure(url: str) -> Engine:
    """Connect to a database. Called once on first use; tests call it to get a fresh database."""
    global _engine, _session_factory
    if _engine is not None:
        _engine.dispose()
    kwargs = {}
    if url.startswith("sqlite"):
        # Requests and the arm worker run on different threads.
        kwargs["connect_args"] = {"check_same_thread": False}
        if url in ("sqlite://", "sqlite:///:memory:"):
            kwargs["poolclass"] = StaticPool  # one shared in-memory database
    _engine = create_engine(url, **kwargs)
    if url.startswith("sqlite"):
        event.listen(_engine, "connect", _sqlite_pragmas)
    _session_factory = sessionmaker(_engine, expire_on_commit=False)
    return _engine


def _sqlite_pragmas(connection, _record):
    cursor = connection.cursor()
    cursor.execute("PRAGMA foreign_keys=ON")
    cursor.execute("PRAGMA journal_mode=WAL")
    cursor.execute("PRAGMA busy_timeout=5000")
    cursor.close()


def get_engine() -> Engine:
    if _engine is None:
        configure(settings.database_url)
    return _engine


def new_session() -> Session:
    get_engine()
    return _session_factory()


@contextmanager
def session_scope():
    """A session that is always closed. Services commit their own changes."""
    session = new_session()
    try:
        yield session
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


def create_tables() -> None:
    """Create missing tables (SQLite demo and tests). On PostgreSQL, schema.sql does this."""
    from . import models  # noqa: F401  (registers the tables)

    Base.metadata.create_all(get_engine())
