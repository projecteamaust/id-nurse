# Database (SQLite)

Single file DB. Enable `PRAGMA journal_mode=WAL` and `PRAGMA foreign_keys=ON`.
Use standard SQL so a later move to PostgreSQL is easy.

| Table | Columns / purpose |
|---|---|
| `users` | id, employee_id (unique), name, password_hash, role (`nurse` or `supervisor`) |
| `patients` | id, file_number (unique), name, diagnosis_code (ICD-10; reserved for future AI) |
| `items` | id, name, sku, slot_number (UNIQUE), quantity, min_quantity |
| `orders` | id, patient_id, nurse_id, status, created_at, approved_at, completed_at |
| `order_items` | id, order_id, item_id, qty_requested, qty_dispensed |
| `poses` | id, slot_number (nullable), pose_name, angles (6 values). Names: `home`, `box`, `approach_slotN`, `grab_slotN` |
| `audit_log` | id, timestamp, actor (user id or system), action, details |

Notes:
- `qty_dispensed` is updated only when a pick succeeds.
- `items.quantity` must never go below 0.
- Seed data: 2 users (one nurse, one supervisor), 2 patients, 6 items (slots 1 to 6).
- Before any demo: change seed passwords and the `SECRET_JWT` value.
