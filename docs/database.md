# Database (SQLite)

Single file DB. Enable `PRAGMA journal_mode=WAL` and `PRAGMA foreign_keys=ON`.
Use standard SQL so a later move to PostgreSQL is easy.

| Table | Columns / purpose |
|---|---|
| `users` | id, employee_id (unique), name, password_hash (nullable, see Login), role (`nurse` or `supervisor`), ward |
| `patients` | id, file_number (unique), name, date_of_birth, room, diagnosis_code (ICD-10; reserved for future AI) |
| `items` | id, name, sku, category (NOT NULL), slot_number (UNIQUE), quantity, min_quantity |
| `orders` | id, patient_id, nurse_id, status, created_at, approved_at, completed_at |
| `order_items` | id, order_id, item_id, qty_requested, qty_dispensed |
| `poses` | id, slot_number (nullable), pose_name, angles (6 values). Names: `home`, `box`, `approach_slotN`, `grab_slotN` |
| `audit_log` | id, timestamp, actor (user id or system), action, details |

Notes:
- `qty_dispensed` is updated only when a pick succeeds.
- `items.quantity` must never go below 0.
- The API returns a patient's `age`, calculated from `date_of_birth` (a stored age would go out of date).
- Seed data: 2 users (one nurse with no password, one supervisor with a password), 2 patients,
  6 items (slots 1 to 6) spread over 3 categories: Wound care, IV and injections, Gloves and protection.
- Before any demo: change the seed supervisor password and the `SECRET_JWT` value.

## Login
- Nurses are identified by `employee_id` alone. Their `password_hash` is NULL.
- A nurse card or QR code stores the same `employee_id` as plain digits, so no extra column is needed.
- Supervisors have a PBKDF2 `password_hash`. Enforced in the schema:
  `CHECK (role = 'nurse' OR password_hash IS NOT NULL)`.
- ID-only nurse login is a known limitation (see CLAUDE.md → Decisions).
