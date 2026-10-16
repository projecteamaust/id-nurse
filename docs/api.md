# API (REST + JSON)

Auth: login returns a JWT (valid 8 hours, configurable). Send it as `Authorization: Bearer <token>`.

| Group | Endpoints | Who | Purpose |
|---|---|---|---|
| Auth/health | `POST /auth/login`, `GET /me`, `GET /health` | public / logged in | login, current user, server status |
| Patients | `/patients` (add, read) | nurse, supervisor | patient data |
| Items | `/items` | read: everyone; edit: supervisor | items and stock |
| Orders | `POST /orders`, `POST /orders/{id}/approve`, `POST /orders/{id}/cancel`, `GET /orders/{id}` | nurse, supervisor | create, approve, cancel, track |
| Reports | `/reports` (dispense CSV, low stock), `/audit` | supervisor | reports and audit log |
| Calibration | `/calibration`, `/calibrate` | supervisor | save poses, move arm, test a pick |

## Order states
`PENDING` -> `DISPENSING` -> `DONE` | `PARTIAL` | `FAILED`
`CANCELLED` is possible only before approval.

## Validation on order creation
- Patient file number exists
- Each item exists and has enough stock
- Quantities are positive and within the configured order limit

## Other
- The frontend polls `GET /orders/{id}` every 1 to 2 seconds until the state is final.
- If the frontend is served from a different origin than the API, add CORS settings (planned task).
- Frozen API contract: ask before renaming or removing endpoints or fields.
