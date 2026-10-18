# Database (PostgreSQL, SQLAlchemy)

The real database is PostgreSQL. `backend/schema.sql` creates every table; `backend/app/models.py` describes
the same tables for SQLAlchemy (a test checks that the two stay the same).
The same code also runs on SQLite, which is used for the tests and for a local demo without PostgreSQL.
The database is chosen only by `DATABASE_URL` in `backend/.env`.

All times are stored in UTC (`TIMESTAMPTZ`); the API shows them in the server's local time.

| Table | Columns / purpose |
|---|---|
| `users` | id, employee_id (unique), name, password_hash (nullable, see Login), role (`nurse` or `supervisor`), ward |
| `patients` | id, file_number (unique), name, date_of_birth, room, diagnosis_code (ICD-10; reserved for future AI) |
| `items` | id, name, sku (unique), category, slot_number (unique, the drawer number), cabinet_row, cabinet_column, quantity, min_quantity |
| `orders` | id, patient_id, nurse_id, status, created_at, approved_at, completed_at |
| `order_items` | id, order_id, item_id, qty_requested, qty_dispensed |
| `dispense_commands` | the arm's work queue: id, order_id (unique), status (`pending`, `in_progress`, `completed`, `failed`), path (JSON list of stops), created_at, started_at, finished_at, error |
| `poses` | id, slot_number (nullable), pose_name (unique), angles (6 values). Names: `home`, `box`, `window`, `approach_slotN`, `grab_slotN` |
| `audit_log` | id, timestamp, actor_id (user id, NULL = the system), action, order_id (nullable), summary, details (JSON) |

Notes:
- Cabinet location: `cabinet_row` 1 = row A (top), `cabinet_column` 1 = left. The API shows it as `cabinet_location`,
  e.g. row 1 column 3 = `"A3"`. Each position holds one drawer (unique row + column).
- `qty_dispensed` is updated only when a pick succeeds. `items.quantity` goes down at the same moment, never at order creation.
- `items.quantity` must never go below 0 (CHECK constraint).
- The API returns a patient's `age`, calculated from `date_of_birth` (a stored age would go out of date).
- `audit_log` rows are only added, never changed or deleted. `order_id` and `summary` are stored because `GET /audit`
  returns them. Problem reports are `audit_log` rows too (see docs/api.md).
- A `dispense_commands` row is added when an order is approved. Its status is the arm's progress; the order status
  (`DISPENSING` -> `DONE | PARTIAL | FAILED`) is what the app shows.
- Seed data (`python -m app.seed`): 2 users (nurse 48216 with no password, supervisor 31082 whose password comes from
  `SEED_SUPERVISOR_PASSWORD`), 2 patients, 6 items in drawers 1 to 6 (A1-A3, B1-B3) over 3 categories:
  Wound care, IV and injections, Gloves and protection.
- Before any demo: set your own `SECRET_JWT` and supervisor password in `backend/.env`.

## Login
- Nurses are identified by `employee_id` alone. Their `password_hash` is NULL.
- A nurse card or QR code stores the same `employee_id` as plain digits, so no extra column is needed.
- Supervisors have a PBKDF2 `password_hash` (200,000 iterations). Enforced in the schema:
  `CHECK (role = 'nurse' OR password_hash IS NOT NULL)`.
- ID-only nurse login is a known limitation (see CLAUDE.md → Decisions).
