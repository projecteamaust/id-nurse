"""Demo data: 2 users, 2 patients, 6 supplies in drawers 1-6.

Run from the backend/ folder:   python -m app.seed
The supervisor password is read from SEED_SUPERVISOR_PASSWORD in .env (never written in code).
Tables are created if they are missing. If there are already users, nothing is changed.
"""

import os
import sys
from datetime import date

from sqlalchemy import select
from sqlalchemy.orm import Session

from . import db
from .models import Item, Patient, User
from .security import hash_password

NURSE_EMPLOYEE_ID = "48216"
SUPERVISOR_EMPLOYEE_ID = "31082"

PATIENTS = [
    # file_number, name, date_of_birth, room, diagnosis_code
    ("284913", "Alex Morgan", date(1992, 3, 14), "2B-12", "T81.4"),
    ("548220", "Sam Taylor", date(1965, 6, 2), "2A-04", "L89.1"),
]

# Two rows of three drawers: slots 1-3 are A1-A3, slots 4-6 are B1-B3.
ITEMS = [
    # name, sku, category, slot, row, column, quantity, min_quantity
    ("Sterile gauze pads", "WC-001", "Wound care", 1, 1, 1, 42, 10),
    ("Adhesive dressing", "WC-002", "Wound care", 2, 1, 2, 9, 10),
    ("IV administration set", "IV-001", "IV and injections", 3, 1, 3, 21, 5),
    ("10 ml syringe", "IV-002", "IV and injections", 4, 2, 1, 0, 10),
    ("Nitrile gloves, M", "GP-001", "Gloves and protection", 5, 2, 2, 64, 20),
    ("Procedure mask", "GP-002", "Gloves and protection", 6, 2, 3, 26, 10),
]


def seed(session: Session, supervisor_password: str) -> bool:
    """Add the demo data to an empty database. Returns False if there was data already."""
    if session.scalar(select(User.id).limit(1)) is not None:
        return False
    session.add_all([
        User(employee_id=NURSE_EMPLOYEE_ID, name="Maya Chen", password_hash=None,
             role="nurse", ward="Ward 4 · Surgical"),
        User(employee_id=SUPERVISOR_EMPLOYEE_ID, name="Elena Ruiz", password_hash=hash_password(supervisor_password),
             role="supervisor", ward="Ward 4 · Surgical"),
    ])
    session.add_all([
        Patient(file_number=f, name=n, date_of_birth=dob, room=r, diagnosis_code=d)
        for f, n, dob, r, d in PATIENTS
    ])
    session.add_all([
        Item(name=n, sku=sku, category=c, slot_number=s, cabinet_row=row, cabinet_column=col,
             quantity=q, min_quantity=m)
        for n, sku, c, s, row, col, q, m in ITEMS
    ])
    session.commit()
    return True


def main() -> int:
    password = os.environ.get("SEED_SUPERVISOR_PASSWORD", "")
    if not password:
        print("SEED_SUPERVISOR_PASSWORD is not set in backend/.env. Set it and run again.")
        return 1
    db.create_tables()
    with db.session_scope() as session:
        if seed(session, password):
            print(f"Demo data added. Nurse: {NURSE_EMPLOYEE_ID}. Supervisor: {SUPERVISOR_EMPLOYEE_ID}.")
        else:
            print("The database already has users, nothing was changed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
