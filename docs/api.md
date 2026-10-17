# API (REST + JSON)

Auth: login returns a JWT (valid 8 hours, configurable). Send it as `Authorization: Bearer <token>`.

| Group | Endpoints | Who | Purpose |
|---|---|---|---|
| Auth/health | `POST /auth/login`, `GET /me`, `GET /health` | public / logged in | login, current user, server status |
| Patients | `/patients` (add, read), `GET /patients/{file_number}` | nurse, supervisor | patient data |
| Items | `/items` | read: everyone; edit: supervisor | items and stock |
| Orders | `POST /orders`, `POST /orders/{id}/approve`, `POST /orders/{id}/cancel`, `GET /orders/{id}`, `GET /orders` | nurse, supervisor | create, approve, cancel, track, list |
| Problem reports | `POST /orders/{id}/report` (nurse, supervisor), `GET /problem-reports`, `POST /problem-reports/{id}/resolve` (supervisor) | see left | report a PARTIAL/FAILED order, list and resolve reports |
| Reports | `/reports` (dispense CSV, low stock), `/audit` | supervisor | reports and audit log |
| Calibration | `/calibration`, `/calibrate` | supervisor | save poses, move arm, test a pick |

## Order states
`PENDING` -> `DISPENSING` -> `DONE` | `PARTIAL` | `FAILED`
`CANCELLED` is possible only before approval.

## Validation on order creation
- Patient file number exists
- Each item exists and has enough stock (otherwise 409)
- Quantities are positive and within the configured order limit: config `MAX_QTY_PER_ITEM`, default 30 (otherwise 422)

## Common rules
- Dates are ISO 8601 strings with a timezone, e.g. `2026-10-16T08:45:12+03:00`.
- Errors use FastAPI's format: `{"detail": "message"}`.
- Status codes: 401 not signed in or bad login, 403 wrong role or not your order, 404 not found,
  409 wrong order state or not enough stock, 422 invalid input.

## Login: `POST /auth/login` (public)
One endpoint for both roles. Request:
```json
// nurse (no password)
{ "employee_id": "48216", "method": "scan" }
// supervisor
{ "employee_id": "31082", "method": "manual", "password": "..." }
```
- `method` is `"scan"` or `"manual"`. The server treats both the same; it is only written to `audit_log`.
- Card/QR mapping: the nurse card or QR code contains the employee ID as plain digits. The scanner
  (keyboard-style card reader or camera) reads that text and the app sends it as `employee_id` with `"method": "scan"`.
- Nurse: no password needed. If one is sent, it is ignored.
- Supervisor: missing or wrong password -> 401.
- Unknown employee ID -> 401 `"No staff ID found"`.
- Every success and failure is logged to `audit_log`.
- ID-only nurse login is a known limitation (see CLAUDE.md -> Decisions).

Response 200:
```json
{ "access_token": "<jwt>", "token_type": "bearer", "expires_in": 28800,
  "user": { "id": 1, "employee_id": "48216", "name": "Maya Chen", "role": "nurse", "ward": "Ward 4 · Surgical" } }
```

## `GET /me`
Returns the `user` object from the login response.

## `GET /patients/{file_number}` (nurse, supervisor)
```json
{ "id": 1, "file_number": "284913", "name": "Alex Morgan", "age": 34, "room": "2B-12", "diagnosis_code": "T81.4" }
```
- `age` is calculated from `date_of_birth`.
- Unknown file number -> 404 `"No patient with this file number"`.

## `GET /items` (everyone)
Optional filters: `?category=Wound care`, `?search=gauze`.
```json
[ { "id": 1, "name": "Sterile gauze pads", "sku": "WC-001", "category": "Wound care",
    "slot_number": 3, "quantity": 42, "min_quantity": 10, "low_stock": false } ]
```
- `low_stock` is `quantity <= min_quantity`. Out of stock means `quantity == 0`.

## `POST /orders` (nurse, supervisor)
```json
{ "patient_file_number": "284913", "items": [ { "item_id": 1, "qty": 3 } ] }
```
Returns 201 with the order object (status `PENDING`).

## `POST /orders/{id}/approve` and `POST /orders/{id}/cancel`
- Approve returns the order object with status `DISPENSING`. Cancel returns it with status `CANCELLED`.
- Both are allowed only when the status is `PENDING` (otherwise 409).
- A nurse can approve or cancel only her own orders (otherwise 403).

## `GET /orders/{id}` (order object)
```json
{ "id": 17, "status": "DISPENSING",
  "patient": { "file_number": "284913", "name": "Alex Morgan" },
  "nurse":   { "employee_id": "48216", "name": "Maya Chen" },
  "created_at": "2026-10-16T08:45:12+03:00", "approved_at": "2026-10-16T08:45:20+03:00", "completed_at": null,
  "items": [ { "item_id": 1, "name": "Sterile gauze pads", "slot_number": 3, "qty_requested": 3, "qty_dispensed": 1 } ] }
```
- The frontend calculates progress ("item x of y", current slot) from `qty_dispensed`.
- For `PARTIAL`, the frontend lists items where `qty_dispensed < qty_requested`.

## `GET /orders` (nurse, supervisor)
Used by the nurse Home screen ("Recent requests"), "My recent requests", and later the supervisor dispensing log.
- `?limit=20` (default 20). Newest first.
- A nurse sees only her own orders. A supervisor sees all orders and can filter with `?nurse_id=` and `?status=`.
```json
[ { "id": 17, "status": "DONE", "patient_file_number": "284913", "nurse_name": "Maya Chen",
    "created_at": "2026-10-16T08:45:12+03:00", "item_count": 3, "total_units": 7 } ]
```

## Problem reports
A nurse reports a `PARTIAL` or `FAILED` order so a supervisor can follow it up.
Reports are stored in `audit_log` (no extra table), and the log is only ever added to:
- Sending a report writes one entry: `action = "problem_reported"`, `actor` = the user who sent it,
  `details` = the order id, the note and the missing items. The report `id` is this entry's id.
- Resolving writes a second entry: `action = "problem_resolved"`, `actor` = the supervisor,
  `details` = `{"report_id": ...}`.
- `status` is worked out, not stored: `resolved` if a `problem_resolved` entry exists for the report, otherwise `open`.

Report object:
```json
{ "id": 52, "order_id": 17, "status": "open", "note": "Drawer 2 looked jammed",
  "nurse": { "employee_id": "48216", "name": "Maya Chen" },
  "missing_items": [ { "item_id": 2, "name": "Adhesive dressing", "slot_number": 2, "qty_missing": 1 } ],
  "created_at": "2026-10-16T08:47:03+03:00", "resolved_at": null, "resolved_by": null }
```
- `nurse` is the user who sent the report.
- `missing_items` is filled in by the server from the order: every line where `qty_dispensed < qty_requested`,
  with `qty_missing = qty_requested - qty_dispensed`. The client never sends it.
- `note` is `null` when none was given. `resolved_by` is `{ "employee_id", "name" }` once resolved.

### `POST /orders/{id}/report` (nurse, supervisor)
```json
{ "note": "Drawer 2 looked jammed" }
```
- `note` is optional (may be left out, `null` or empty), at most 200 characters (otherwise 422).
- Allowed only when the order is `PARTIAL` or `FAILED` (otherwise 409).
- A nurse can report only her own orders (otherwise 403).
- At most one open report per order: a second one while the first is open -> 409 `"This order already has an open report"`.
- Returns 201 with the report object (status `open`).

### `GET /problem-reports` (supervisor)
- `?status=open` (default), `resolved` or `all`. Newest first.
- Returns a list of report objects.

### `POST /problem-reports/{id}/resolve` (supervisor)
- Returns the report object with `status: "resolved"`, `resolved_at` and `resolved_by` filled in.
- Unknown report -> 404. Already resolved -> 409 `"Report is already resolved"`.

## Not in the API yet (later)
Notify admin, door/collect, retry a failed order, user management, settings.

## Other
- The frontend polls `GET /orders/{id}` every 1 to 2 seconds until the state is final.
- If the frontend is served from a different origin than the API, add CORS settings (planned task).
- Frozen API contract: ask before renaming or removing endpoints or fields.
