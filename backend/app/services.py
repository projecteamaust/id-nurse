"""All business logic. Routes in main.py only check the role and call these functions.

This file must not import FastAPI. Every function gets a database session, does its work,
writes to audit_log where needed and commits. Errors are raised as ServiceError subclasses;
main.py turns them into HTTP responses ({"detail": "..."}).
"""

import csv
import io
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta

from sqlalchemy import select, update
from sqlalchemy.orm import Session, selectinload

from .config import settings
from .db import utc_now
from .models import AuditLog, DispenseCommand, Item, Order, OrderItem, Patient, Pose, User
from .security import create_token, read_token, token_lifetime_seconds, verify_password

MAX_ITEM_QUANTITY = 999  # PATCH /items/{id}
MAX_REPORT_NOTE_LENGTH = 200  # POST /orders/{id}/report
MAX_LIST_LIMIT = 500  # GET /orders and GET /audit


# ---------------------------------------------------------------- errors


class ServiceError(Exception):
    status_code = 400

    def __init__(self, detail: str):
        super().__init__(detail)
        self.detail = detail


class NotSignedIn(ServiceError):
    status_code = 401


class Forbidden(ServiceError):
    status_code = 403


class NotFound(ServiceError):
    status_code = 404


class Conflict(ServiceError):
    """Wrong order state or not enough stock."""

    status_code = 409


class Invalid(ServiceError):
    status_code = 422


# ---------------------------------------------------------------- helpers


def iso(value: datetime | None) -> str | None:
    """ISO 8601 in the server's local time with its offset, e.g. 2026-10-16T08:45:12+03:00."""
    return None if value is None else value.astimezone().isoformat(timespec="seconds")


def _age(date_of_birth: date, today: date) -> int:
    had_birthday = (today.month, today.day) >= (date_of_birth.month, date_of_birth.day)
    return today.year - date_of_birth.year - (0 if had_birthday else 1)


def _day_range(date_from: date | None, date_to: date | None) -> tuple[datetime | None, datetime | None]:
    """?from= and ?to= (both inclusive) as [start, end) times, using the server's local date."""
    if date_from and date_to and date_from > date_to:
        raise Invalid("from must not be after to")
    start = datetime.combine(date_from, time.min).astimezone() if date_from else None
    end = datetime.combine(date_to + timedelta(days=1), time.min).astimezone() if date_to else None
    return start, end


def _clamp_limit(limit: int) -> int:
    return max(1, min(limit, MAX_LIST_LIMIT))


def _audit(session: Session, actor: User | None, action: str, summary: str,
           order_id: int | None = None, details: dict | None = None) -> AuditLog:
    """Adds one audit_log row. actor None = the system (the robot). The caller commits."""
    entry = AuditLog(timestamp=utc_now(), actor_id=actor.id if actor else None, action=action,
                     order_id=order_id, summary=summary, details=details or {})
    session.add(entry)
    return entry


def _plural(count: int, word: str) -> str:
    return f"{count} {word}" if count == 1 else f"{count} {word}s"


def user_json(user: User) -> dict:
    return {"id": user.id, "employee_id": user.employee_id, "name": user.name, "role": user.role, "ward": user.ward}


def _person(user: User | None) -> dict | None:
    return None if user is None else {"employee_id": user.employee_id, "name": user.name}


def _item_json(item: Item) -> dict:
    return {
        "id": item.id,
        "name": item.name,
        "sku": item.sku,
        "category": item.category,
        "slot_number": item.slot_number,
        "cabinet_location": item.cabinet_location,
        "quantity": item.quantity,
        "min_quantity": item.min_quantity,
        "low_stock": item.quantity <= item.min_quantity,
    }


def _order_json(order: Order) -> dict:
    return {
        "id": order.id,
        "status": order.status,
        "patient": {"file_number": order.patient.file_number, "name": order.patient.name},
        "nurse": _person(order.nurse),
        "created_at": iso(order.created_at),
        "approved_at": iso(order.approved_at),
        "completed_at": iso(order.completed_at),
        "items": [
            {
                "item_id": line.item_id,
                "name": line.item.name,
                "slot_number": line.item.slot_number,
                "cabinet_location": line.item.cabinet_location,
                "qty_requested": line.qty_requested,
                "qty_dispensed": line.qty_dispensed,
            }
            for line in order.lines
        ],
    }


def _order_query():
    return select(Order).options(
        selectinload(Order.patient),
        selectinload(Order.nurse),
        selectinload(Order.lines).selectinload(OrderItem.item),
    )


# ---------------------------------------------------------------- auth


def login(session: Session, employee_id: str, method: str, password: str | None) -> dict:
    """POST /auth/login. Nurses need only their ID; supervisors also need their password."""
    employee_id = employee_id.strip()
    user = session.scalar(select(User).where(User.employee_id == employee_id))
    if user is None:
        _audit(session, None, "login_failed", f"Sign in failed: no staff ID {employee_id}",
               details={"employee_id": employee_id, "method": method})
        session.commit()
        raise NotSignedIn("No staff ID found")
    if user.role == "supervisor" and not verify_password(password or "", user.password_hash):
        _audit(session, user, "login_failed", "Sign in failed: wrong password", details={"method": method})
        session.commit()
        raise NotSignedIn("Wrong password")
    # A nurse's password, if one is sent, is ignored (docs/api.md).
    how = "card scan" if method == "scan" else "employee ID"
    _audit(session, user, "login_success", f"{user.name} signed in ({how})", details={"method": method})
    session.commit()
    return {
        "access_token": create_token(user.id, user.role),
        "token_type": "bearer",
        "expires_in": token_lifetime_seconds(),
        "user": user_json(user),
    }


def user_from_token(session: Session, token: str | None) -> User:
    if not token:
        raise NotSignedIn("Not signed in")
    user_id = read_token(token)
    user = session.get(User, user_id) if user_id is not None else None
    if user is None:
        raise NotSignedIn("Invalid or expired token")
    return user


def list_users(session: Session, role: str | None = None) -> list[dict]:
    query = select(User).order_by(User.name)
    if role:
        query = query.where(User.role == role)
    return [user_json(u) for u in session.scalars(query)]


# ---------------------------------------------------------------- patients and items


def get_patient(session: Session, file_number: str) -> dict:
    patient = session.scalar(select(Patient).where(Patient.file_number == file_number))
    if patient is None:
        raise NotFound("No patient with this file number")
    return {
        "id": patient.id,
        "file_number": patient.file_number,
        "name": patient.name,
        "age": _age(patient.date_of_birth, date.today()),
        "room": patient.room,
        "diagnosis_code": patient.diagnosis_code,
    }


def list_items(session: Session, category: str | None = None, search: str | None = None) -> list[dict]:
    query = select(Item).order_by(Item.slot_number)
    if category:
        query = query.where(Item.category == category)
    if search and search.strip():
        query = query.where(Item.name.icontains(search.strip(), autoescape=True))
    return [_item_json(i) for i in session.scalars(query)]


def update_item_quantity(session: Session, user: User, item_id: int, quantity: int) -> dict:
    """PATCH /items/{id}: set the stock count after a refill or a stock check."""
    if not 0 <= quantity <= MAX_ITEM_QUANTITY:
        raise Invalid(f"Quantity must be between 0 and {MAX_ITEM_QUANTITY}")
    item = session.get(Item, item_id)
    if item is None:
        raise NotFound("Item not found")
    old = item.quantity
    item.quantity = quantity
    _audit(session, user, "stock_edit", f"Set {item.name} to {quantity} units (was {old})",
           details={"item_id": item.id, "old_quantity": old, "new_quantity": quantity})
    session.commit()
    return _item_json(item)


def low_stock(session: Session) -> list[dict]:
    """GET /reports/low-stock: items at or below their minimum, lowest stock first."""
    query = select(Item).where(Item.quantity <= Item.min_quantity).order_by(Item.quantity, Item.name)
    return [{**_item_json(i), "qty_to_minimum": i.min_quantity - i.quantity} for i in session.scalars(query)]


# ---------------------------------------------------------------- orders


def create_order(session: Session, user: User, patient_file_number: str, lines: list[tuple[int, int]]) -> dict:
    """POST /orders. Checks the order, then saves it as PENDING. Stock does NOT change here."""
    max_qty = settings.max_qty_per_item
    if not lines:
        raise Invalid("Order has no items")
    if any(not 1 <= qty <= max_qty for _, qty in lines):
        raise Invalid(f"Quantity must be between 1 and {max_qty}")
    if len({item_id for item_id, _ in lines}) != len(lines):
        raise Invalid("Each item can be in an order only once")
    patient = session.scalar(select(Patient).where(Patient.file_number == patient_file_number))
    if patient is None:
        raise NotFound("No patient with this file number")

    order = Order(patient_id=patient.id, nurse_id=user.id, status="PENDING", created_at=utc_now())
    for item_id, qty in lines:
        item = session.get(Item, item_id)
        if item is None:
            raise Conflict(f"Item {item_id} does not exist")
        if item.quantity < qty:
            raise Conflict(f"Not enough stock for {item.name}")
        order.lines.append(OrderItem(item_id=item.id, qty_requested=qty, qty_dispensed=0))
    session.add(order)
    session.flush()  # gives the order its id

    units = sum(qty for _, qty in lines)
    _audit(session, user, "order_created",
           f"Created order #{order.id} for patient {patient.file_number} "
           f"({_plural(len(lines), 'item')}, {_plural(units, 'unit')})",
           order_id=order.id)
    session.commit()
    return _load_order_json(session, order.id)


def _load_order(session: Session, order_id: int) -> Order | None:
    return session.scalar(_order_query().where(Order.id == order_id))


def _load_order_json(session: Session, order_id: int) -> dict:
    session.expire_all()  # read the saved state, not what is cached in the session
    return _order_json(_load_order(session, order_id))


def _visible_order(session: Session, user: User, order_id: int) -> Order:
    """The order, if this user may see it: a nurse only her own, a supervisor every order."""
    order = _load_order(session, order_id)
    if order is None:
        raise NotFound("Order not found")
    if user.role != "supervisor" and order.nurse_id != user.id:
        raise Forbidden("Not your order")
    return order


def _own_pending_order(session: Session, user: User, order_id: int) -> Order:
    order = _visible_order(session, user, order_id)
    if order.status != "PENDING":
        raise Conflict(f"Order is {order.status}, not PENDING")
    return order


def get_order(session: Session, user: User, order_id: int) -> dict:
    return _order_json(_visible_order(session, user, order_id))


def approve_order(session: Session, user: User, order_id: int) -> dict:
    """POST /orders/{id}/approve: PENDING -> DISPENSING and a new command in the arm's queue."""
    order = _own_pending_order(session, user, order_id)
    now = utc_now()
    order.status = "DISPENSING"
    order.approved_at = now
    session.add(DispenseCommand(order_id=order.id, status="pending", path=build_path(order.lines), created_at=now))
    _audit(session, user, "order_approved", f"Approved order #{order.id}", order_id=order.id)
    session.commit()
    return _load_order_json(session, order.id)


def cancel_order(session: Session, user: User, order_id: int) -> dict:
    """POST /orders/{id}/cancel: only before approval."""
    order = _own_pending_order(session, user, order_id)
    order.status = "CANCELLED"
    _audit(session, user, "order_cancelled", f"Cancelled order #{order.id}", order_id=order.id)
    session.commit()
    return _load_order_json(session, order.id)


def list_orders(session: Session, user: User, limit: int = 20, nurse_id: int | None = None,
                status: str | None = None, date_from: date | None = None, date_to: date | None = None) -> list[dict]:
    """GET /orders, newest first. A nurse sees only her own orders."""
    start, end = _day_range(date_from, date_to)
    query = select(Order).options(selectinload(Order.patient), selectinload(Order.nurse), selectinload(Order.lines))
    if user.role != "supervisor":
        query = query.where(Order.nurse_id == user.id)
    elif nurse_id is not None:
        query = query.where(Order.nurse_id == nurse_id)
    if status:
        query = query.where(Order.status == status)
    if start:
        query = query.where(Order.created_at >= start)
    if end:
        query = query.where(Order.created_at < end)
    query = query.order_by(Order.id.desc()).limit(_clamp_limit(limit))
    return [
        {
            "id": o.id,
            "status": o.status,
            "patient_file_number": o.patient.file_number,
            "nurse_name": o.nurse.name,
            "created_at": iso(o.created_at),
            "item_count": len(o.lines),
            "total_units": sum(line.qty_requested for line in o.lines),
        }
        for o in session.scalars(query)
    ]


# ---------------------------------------------------------------- robot arm queue
# Used by worker.py. The worker takes the next command, asks the arm to pick each unit,
# and reports every pick and the delivery here.


@dataclass(frozen=True)
class PickStep:
    """One unit to pick from one drawer."""

    item_id: int
    name: str
    slot_number: int
    cabinet_location: str


@dataclass(frozen=True)
class DispenseJob:
    command_id: int
    order_id: int
    picks: list[PickStep]  # one per unit still to pick, sorted by cabinet location (the pickup path)
    already_dispensed: int  # units picked before a restart


def _by_location(lines: list[OrderItem]) -> list[OrderItem]:
    """Top row first, left to right in each row: the arm's path through the cabinet."""
    return sorted(lines, key=lambda line: (line.item.cabinet_row, line.item.cabinet_column))


def build_path(lines: list[OrderItem]) -> list[dict]:
    """The arm's stops for one order: home -> each drawer (sorted by location) -> pickup window -> home."""
    drawers = [
        {"stop": "drawer", "slot_number": line.item.slot_number, "cabinet_location": line.item.cabinet_location,
         "item_id": line.item_id, "qty": line.qty_requested}
        for line in _by_location(lines)
    ]
    return [{"stop": "home"}, *drawers, {"stop": "pickup_window"}, {"stop": "home"}]


def claim_next_command(session: Session) -> DispenseJob | None:
    """Takes the oldest pending command, marks it in_progress and returns what the arm must pick."""
    command = session.scalar(
        select(DispenseCommand)
        .where(DispenseCommand.status == "pending")
        .order_by(DispenseCommand.id)
        .limit(1)
        .with_for_update(skip_locked=True)  # PostgreSQL: never give one command to two workers
    )
    if command is None:
        return None
    command.status = "in_progress"
    command.started_at = utc_now()
    session.commit()

    order = _load_order(session, command.order_id)
    picks = []
    for line in _by_location(order.lines):
        step = PickStep(line.item_id, line.item.name, line.item.slot_number, line.item.cabinet_location)
        picks.extend([step] * (line.qty_requested - line.qty_dispensed))
    already = sum(line.qty_dispensed for line in order.lines)
    return DispenseJob(command.id, order.id, picks, already)


def drawer_has_stock(session: Session, item_id: int) -> bool:
    return session.scalar(select(Item.quantity).where(Item.id == item_id)) > 0


def record_pick_ok(session: Session, order_id: int, step: PickStep) -> None:
    """The arm put one unit in the box: stock -1, qty_dispensed +1 and the audit row, in one transaction.

    This is the only place where stock goes down (never at order creation).
    """
    # "quantity > 0" keeps the stock from going below 0 even if someone edited it during the pick.
    session.execute(update(Item).where(Item.id == step.item_id, Item.quantity > 0)
                    .values(quantity=Item.quantity - 1))
    session.execute(update(OrderItem).where(OrderItem.order_id == order_id, OrderItem.item_id == step.item_id)
                    .values(qty_dispensed=OrderItem.qty_dispensed + 1))
    _audit(session, None, "pick_ok", f"Picked 1 × {step.name} (slot {step.slot_number}, {step.cabinet_location})",
           order_id=order_id, details={"item_id": step.item_id, "slot_number": step.slot_number})
    session.commit()


def record_pick_failed(session: Session, order_id: int, step: PickStep, reason: str, will_retry: bool) -> None:
    then = "trying again" if will_retry else "stopping"
    _audit(session, None, "pick_failed",
           f"Pick failed: {step.name} (slot {step.slot_number}, {step.cabinet_location}), {reason}, {then}",
           order_id=order_id,
           details={"item_id": step.item_id, "slot_number": step.slot_number, "reason": reason, "retry": will_retry})
    session.commit()


def finish_command(session: Session, command_id: int, delivered: bool, error: str | None = None) -> str:
    """The arm is done with an order. Sets the final order state and returns it.

    DONE = everything picked and delivered, PARTIAL = some picked and delivered,
    FAILED = nothing picked, or the box could not be delivered.
    """
    command = session.get(DispenseCommand, command_id)
    order = _load_order(session, command.order_id)
    requested = sum(line.qty_requested for line in order.lines)
    dispensed = sum(line.qty_dispensed for line in order.lines)
    if not delivered or dispensed == 0:
        status = "FAILED"
    elif dispensed == requested:
        status = "DONE"
    else:
        status = "PARTIAL"
    now = utc_now()
    order.status = status
    order.completed_at = now
    command.status = "completed" if delivered else "failed"
    command.finished_at = now
    command.error = error
    summary = f"Order #{order.id} finished: {status} ({dispensed} of {requested} units)"
    if error:
        summary += f", {error}"
    _audit(session, None, "order_finished", summary, order_id=order.id,
           details={"status": status, "dispensed": dispensed, "requested": requested, "error": error})
    session.commit()
    return status


def recover_interrupted_commands(session: Session) -> int:
    """After a restart: commands that were in_progress go back to pending (picked units stay picked)."""
    result = session.execute(update(DispenseCommand).where(DispenseCommand.status == "in_progress")
                             .values(status="pending"))
    session.commit()
    return result.rowcount


def load_poses(session: Session) -> dict[str, list[int]]:
    """Saved arm angles by pose name, for the real arm."""
    return {p.pose_name: list(p.angles) for p in session.scalars(select(Pose))}


# ---------------------------------------------------------------- audit log and reports


def list_audit(session: Session, limit: int = 100, nurse_id: int | None = None,
               date_from: date | None = None, date_to: date | None = None) -> list[dict]:
    """GET /audit, newest first. nurse_id keeps only actions done by that user."""
    start, end = _day_range(date_from, date_to)
    query = select(AuditLog).options(selectinload(AuditLog.actor))
    if nurse_id is not None:
        query = query.where(AuditLog.actor_id == nurse_id)
    if start:
        query = query.where(AuditLog.timestamp >= start)
    if end:
        query = query.where(AuditLog.timestamp < end)
    query = query.order_by(AuditLog.id.desc()).limit(_clamp_limit(limit))
    return [
        {"id": e.id, "timestamp": iso(e.timestamp), "actor": _person(e.actor), "action": e.action,
         "order_id": e.order_id, "summary": e.summary}
        for e in session.scalars(query)
    ]


DISPENSE_CSV_COLUMNS = [
    "order_id", "created_at", "completed_at", "status", "patient_file_number", "nurse_employee_id",
    "nurse_name", "item_name", "slot_number", "qty_requested", "qty_dispensed",
]


def dispense_csv(session: Session, nurse_id: int | None = None,
                 date_from: date | None = None, date_to: date | None = None) -> str:
    """GET /reports/dispense.csv: one row per order line, oldest first, cancelled orders left out."""
    start, end = _day_range(date_from, date_to)
    query = _order_query().where(Order.status != "CANCELLED")
    if nurse_id is not None:
        query = query.where(Order.nurse_id == nurse_id)
    if start:
        query = query.where(Order.created_at >= start)
    if end:
        query = query.where(Order.created_at < end)
    out = io.StringIO()
    writer = csv.writer(out, lineterminator="\n")  # quotes text with a comma or a quote (standard CSV)
    writer.writerow(DISPENSE_CSV_COLUMNS)
    for order in session.scalars(query.order_by(Order.id)):
        for line in order.lines:
            writer.writerow([
                order.id, iso(order.created_at), iso(order.completed_at) or "", order.status,
                order.patient.file_number, order.nurse.employee_id, order.nurse.name,
                line.item.name, line.item.slot_number, line.qty_requested, line.qty_dispensed,
            ])
    return out.getvalue()


# ---------------------------------------------------------------- problem reports
# Stored in audit_log (docs/api.md): a "problem_reported" entry is the report (its id is the
# report id); a later "problem_resolved" entry marks it resolved. The status is worked out.


def _resolutions(session: Session, order_ids: list[int] | None = None) -> dict[int, AuditLog]:
    """{report id: its problem_resolved entry}."""
    query = select(AuditLog).options(selectinload(AuditLog.actor)).where(AuditLog.action == "problem_resolved")
    if order_ids is not None:
        query = query.where(AuditLog.order_id.in_(order_ids))
    return {int(e.details["report_id"]): e for e in session.scalars(query)}


def _report_json(entry: AuditLog, resolved: AuditLog | None) -> dict:
    return {
        "id": entry.id,
        "order_id": entry.order_id,
        "status": "open" if resolved is None else "resolved",
        "note": entry.details.get("note"),
        "nurse": _person(entry.actor),
        "missing_items": entry.details.get("missing_items", []),
        "created_at": iso(entry.timestamp),
        "resolved_at": iso(resolved.timestamp) if resolved else None,
        "resolved_by": _person(resolved.actor) if resolved else None,
    }


def report_problem(session: Session, user: User, order_id: int, note: str | None) -> dict:
    """POST /orders/{id}/report: only for PARTIAL or FAILED orders, one open report per order."""
    order = _visible_order(session, user, order_id)
    text = note.strip() if note and note.strip() else None
    if text is not None and len(text) > MAX_REPORT_NOTE_LENGTH:
        raise Invalid(f"Note must be at most {MAX_REPORT_NOTE_LENGTH} characters")
    if order.status not in ("PARTIAL", "FAILED"):
        raise Conflict(f"Order is {order.status}, not PARTIAL or FAILED")
    reports = session.scalars(select(AuditLog.id).where(AuditLog.action == "problem_reported",
                                                        AuditLog.order_id == order.id)).all()
    resolved = _resolutions(session, [order.id])
    if any(report_id not in resolved for report_id in reports):
        raise Conflict("This order already has an open report")

    missing = [
        {"item_id": line.item_id, "name": line.item.name, "slot_number": line.item.slot_number,
         "qty_missing": line.qty_requested - line.qty_dispensed}
        for line in order.lines
        if line.qty_dispensed < line.qty_requested
    ]
    entry = _audit(session, user, "problem_reported", f"Reported a problem with order #{order.id}",
                   order_id=order.id, details={"order_id": order.id, "note": text, "missing_items": missing})
    session.commit()
    entry.actor = user
    return _report_json(entry, None)


def list_problem_reports(session: Session, status: str = "open") -> list[dict]:
    """GET /problem-reports?status=open|resolved|all, newest first."""
    entries = session.scalars(select(AuditLog).options(selectinload(AuditLog.actor))
                              .where(AuditLog.action == "problem_reported").order_by(AuditLog.id.desc()))
    resolved = _resolutions(session)
    reports = [_report_json(e, resolved.get(e.id)) for e in entries]
    return reports if status == "all" else [r for r in reports if r["status"] == status]


def resolve_problem_report(session: Session, user: User, report_id: int) -> dict:
    entry = session.scalar(select(AuditLog).options(selectinload(AuditLog.actor))
                           .where(AuditLog.id == report_id, AuditLog.action == "problem_reported"))
    if entry is None:
        raise NotFound("Report not found")
    if report_id in _resolutions(session, [entry.order_id]):
        raise Conflict("Report is already resolved")
    resolution = _audit(session, user, "problem_resolved", f"Resolved the problem report for order #{entry.order_id}",
                        order_id=entry.order_id, details={"report_id": report_id})
    session.commit()
    resolution.actor = user
    return _report_json(entry, resolution)
