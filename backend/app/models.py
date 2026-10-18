"""Database tables. backend/schema.sql creates the same tables on PostgreSQL."""

from datetime import date, datetime

from sqlalchemy import JSON, CheckConstraint, Date, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .db import Base, UTCDateTime

# JSON on SQLite, JSONB on PostgreSQL.
JsonType = JSON().with_variant(JSONB(), "postgresql")

ROLES = ("nurse", "supervisor")
ORDER_STATUSES = ("PENDING", "DISPENSING", "DONE", "PARTIAL", "FAILED", "CANCELLED")
FINAL_ORDER_STATUSES = ("DONE", "PARTIAL", "FAILED", "CANCELLED")
COMMAND_STATUSES = ("pending", "in_progress", "completed", "failed")


def _in(column: str, values: tuple[str, ...]) -> str:
    return f"{column} IN ({', '.join(repr(v) for v in values)})"


class User(Base):
    __tablename__ = "users"
    __table_args__ = (
        CheckConstraint(_in("role", ROLES), name="users_role_check"),
        # Nurses sign in with their ID only; supervisors must have a password.
        CheckConstraint("role = 'nurse' OR password_hash IS NOT NULL", name="users_password_check"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    employee_id: Mapped[str] = mapped_column(String(20), unique=True)
    name: Mapped[str] = mapped_column(String(100))
    password_hash: Mapped[str | None] = mapped_column(String(255))
    role: Mapped[str] = mapped_column(String(20))
    ward: Mapped[str] = mapped_column(String(100))


class Patient(Base):
    __tablename__ = "patients"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    file_number: Mapped[str] = mapped_column(String(20), unique=True)
    name: Mapped[str] = mapped_column(String(100))
    date_of_birth: Mapped[date] = mapped_column(Date)
    room: Mapped[str] = mapped_column(String(20))
    diagnosis_code: Mapped[str] = mapped_column(String(20))  # ICD-10, reserved for future AI


class Item(Base):
    """One supply in one numbered drawer of the cabinet."""

    __tablename__ = "items"
    __table_args__ = (
        UniqueConstraint("cabinet_row", "cabinet_column", name="items_cabinet_position_key"),
        CheckConstraint("quantity >= 0", name="items_quantity_check"),
        CheckConstraint("min_quantity >= 0", name="items_min_quantity_check"),
        CheckConstraint("cabinet_row >= 1 AND cabinet_column >= 1", name="items_cabinet_position_check"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    sku: Mapped[str] = mapped_column(String(30), unique=True)
    category: Mapped[str] = mapped_column(String(50))
    slot_number: Mapped[int] = mapped_column(Integer, unique=True)  # the drawer number
    cabinet_row: Mapped[int] = mapped_column(Integer)  # 1 = row A (top)
    cabinet_column: Mapped[int] = mapped_column(Integer)  # 1 = left
    quantity: Mapped[int] = mapped_column(Integer)
    min_quantity: Mapped[int] = mapped_column(Integer)

    @property
    def cabinet_location(self) -> str:
        """Drawer label shown to people, e.g. row 1 column 3 -> "A3"."""
        return f"{chr(ord('A') + self.cabinet_row - 1)}{self.cabinet_column}"


class Order(Base):
    __tablename__ = "orders"
    __table_args__ = (CheckConstraint(_in("status", ORDER_STATUSES), name="orders_status_check"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    patient_id: Mapped[int] = mapped_column(ForeignKey("patients.id"))
    nurse_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    status: Mapped[str] = mapped_column(String(20))
    created_at: Mapped[datetime] = mapped_column(UTCDateTime, index=True)
    approved_at: Mapped[datetime | None] = mapped_column(UTCDateTime)
    completed_at: Mapped[datetime | None] = mapped_column(UTCDateTime)

    patient: Mapped[Patient] = relationship()
    nurse: Mapped[User] = relationship()
    lines: Mapped[list["OrderItem"]] = relationship(order_by="OrderItem.id", back_populates="order")


class OrderItem(Base):
    __tablename__ = "order_items"
    __table_args__ = (
        CheckConstraint("qty_requested > 0", name="order_items_qty_requested_check"),
        CheckConstraint("qty_dispensed >= 0 AND qty_dispensed <= qty_requested", name="order_items_qty_dispensed_check"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    order_id: Mapped[int] = mapped_column(ForeignKey("orders.id"), index=True)
    item_id: Mapped[int] = mapped_column(ForeignKey("items.id"))
    qty_requested: Mapped[int] = mapped_column(Integer)
    qty_dispensed: Mapped[int] = mapped_column(Integer, default=0)

    order: Mapped[Order] = relationship(back_populates="lines")
    item: Mapped[Item] = relationship()


class DispenseCommand(Base):
    """The robot arm's work queue: one command per approved order."""

    __tablename__ = "dispense_commands"
    __table_args__ = (CheckConstraint(_in("status", COMMAND_STATUSES), name="dispense_commands_status_check"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    order_id: Mapped[int] = mapped_column(ForeignKey("orders.id"), unique=True)
    status: Mapped[str] = mapped_column(String(20))
    path: Mapped[list] = mapped_column(JsonType)  # ordered stops: home -> drawers -> pickup window -> home
    created_at: Mapped[datetime] = mapped_column(UTCDateTime)
    started_at: Mapped[datetime | None] = mapped_column(UTCDateTime)
    finished_at: Mapped[datetime | None] = mapped_column(UTCDateTime)
    error: Mapped[str | None] = mapped_column(Text)

    order: Mapped[Order] = relationship()


class Pose(Base):
    """Saved arm angles for calibration (Repeat and Teach). Used later by the real arm."""

    __tablename__ = "poses"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    slot_number: Mapped[int | None] = mapped_column(Integer)
    pose_name: Mapped[str] = mapped_column(String(50), unique=True)  # home, box, window, approach_slotN, grab_slotN
    angles: Mapped[list] = mapped_column(JsonType)  # 6 values; the last one is the gripper


class AuditLog(Base):
    """Every important action. Rows are only ever added, never changed or deleted."""

    __tablename__ = "audit_log"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    timestamp: Mapped[datetime] = mapped_column(UTCDateTime, index=True)
    actor_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"))  # NULL = the system (robot)
    action: Mapped[str] = mapped_column(String(40))
    order_id: Mapped[int | None] = mapped_column(ForeignKey("orders.id"), index=True)
    summary: Mapped[str] = mapped_column(Text)
    details: Mapped[dict] = mapped_column(JsonType, default=dict)

    actor: Mapped[User | None] = relationship()
