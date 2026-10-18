# ID Nurse

Graduation project: a smart system for managing and dispensing non-pharmaceutical medical supplies.
A nurse enters a patient file number, picks items and quantities, approves the order, and a robot arm
picks the items from a cabinet into a pickup box. Every action is logged for auditing and insurance claims.

Two parts in one repo:
- Backend (Python/FastAPI, PostgreSQL via SQLAlchemy) in `backend/`
- Frontend (Flutter) in `frontend/`

Detailed specs live in `docs/`. Read the relevant file before working on that area:
- `docs/database.md`: tables and columns
- `docs/api.md`: endpoints, roles, order states (the contract between frontend and backend)
- `docs/order-flow-and-arm.md`: order flow, arm queue and worker, ArmDriver, Serial protocol
- `docs/prototype-review.md`: every prototype screen with its text, colors, fonts, actions and API calls
- `design/prototype/`: Figma prototype code (`src/App.tsx` screens, `src/index.css` colors/fonts)

## Current build order
1. Tiny backend skeleton with /health (so the project runs and the API contract exists)
2. Flutter frontend, screen by screen, using MockApiService (fake data)
3. Real backend: database + seed, login, orders, dispensing with the arm simulator (done)
4. Connect the Flutter screens to the real API: RealApiService, mock kept as a fallback (done)
5. Real arm (Arduino) much later

## Decisions
Decisions about the Figma prototype. Where the prototype differs, these win.
1. Nurse login has no password: scan a card/QR (simulated in the demo) or type the employee ID.
   Supervisors sign in with employee ID + password.
2. Cancel is allowed only before approval (`PENDING`). The dispensing screen has no cancel button.
3. No "continue without this item". The backend retries once, then ends the order as `PARTIAL` or `FAILED`,
   and the screen shows the result.
4. No supervisor co-approval for large quantities (future feature).
5. Admin console: only stock, low stock, dispensing log and report export. Other prototype admin pages may come later.
6. Order states stay `PENDING -> DISPENSING -> DONE | PARTIAL | FAILED`. There is a PARTIAL result screen.
   "Collect" and "Complete" are frontend-only steps shown after `DONE`.
7. English only, left-to-right, IBM Plex Sans font.
8. Items have a `category`. Users have a `ward`. Patients have a date of birth (age is shown) and a room.

Known limitation (mention it in the graduation report): with ID-only nurse login, anyone who knows or copies
a nurse's employee ID can sign in as that nurse. Accepted for the prototype. Future fix: PIN or encrypted badge.

Work on ONE part and ONE task at a time. Do not build backend and frontend features in the same task.

## Rules for everything
- Use plan mode: show the plan, wait for my OK, then implement.
- Do not build features I did not ask for. Do not add new languages or frameworks without asking.
- Explain what you changed in simple terms; I must be able to explain it in my graduation defense.
- Keep changes inside the files needed for the task. Small, commit-sized steps.
- Never put real passwords or secrets in code or prompts.
- Run the tests/analysis for the part you changed and show me the result before saying a task is done.

---

## Backend (Python, in backend/)

### Stack
- Python 3.10+, FastAPI, Uvicorn, Pydantic
- PostgreSQL via SQLAlchemy 2 (psycopg driver). The same code runs on SQLite for tests and the local demo.
  The database is chosen only by `DATABASE_URL` in `backend/.env`
- `backend/schema.sql` creates the PostgreSQL tables; it must match `app/models.py` (checked by `tests/test_schema.py`)
- PyJWT for tokens, `hashlib` PBKDF2 (200,000 iterations) for passwords
- python-dotenv reads `backend/.env`; pyserial (real arm only); openpyxl and reportlab (reports, later phase)
- Tests: built-in `unittest` (FastAPI TestClient, in-memory SQLite, arm simulator)

### Layout
```
backend/
  .env.example  every setting with a placeholder (copy to .env; .env is never committed)
  requirements.txt
  schema.sql    PostgreSQL tables (for the shared database)
  app/
    config.py   all settings from environment variables / .env
    db.py       engine, sessions, UTC date type, create_tables (SQLite demo/tests)
    models.py   SQLAlchemy tables
    schemas.py  Pydantic request/response shapes (field names = docs/api.md)
    security.py password hashing, JWT
    services.py ALL business logic, incl. the arm queue (must NOT import FastAPI)
    arm.py      ArmDriver interface, SimulatedArm, SerialArm
    worker.py   ArmWorker: background thread that takes queued orders and drives the arm
    main.py     thin API routes + role checks; only calls services
    seed.py     demo data: 2 users, 2 patients, 6 items in drawers 1-6
  tests/        unittest files (each starts with `import tests` to load the test settings)
static/          calibrate.html (supervisor arm calibration page, later)
firmware/arm_controller/   Arduino sketch (later)
docs/            specs
design/          Figma prototype (design/prototype/)
frontend/        Flutter app
```

### Backend rules
1. Business logic goes in `services.py`; routes in `main.py` stay thin.
2. Never store or log plain-text passwords. Secrets come from env (`SECRET_JWT`, `DATABASE_URL`,
   `SEED_SUPERVISOR_PASSWORD`), never hardcoded. The app refuses to start without `SECRET_JWT`.
3. Stock decreases ONLY after a successful physical pick, never at order creation.
4. Every important action writes to `audit_log`: login success/failure, order create/approve/cancel,
   pick results, order finished, stock edits, pose saves, problem reports.
5. Roles: `nurse` and `supervisor`. A nurse can approve/cancel only her own orders; a supervisor can do anything.
6. Default arm mode is `mock` (the simulator). The real arm is selected by config (`ARM_MODE=real`), never by editing code.
7. Server runs on 127.0.0.1 only, with ONE process (one arm = one worker). Do not use `--workers`.
8. Every new backend feature comes with tests.
9. Do not rename or remove endpoints or fields in docs/api.md without asking (frontend depends on them).
10. A table change goes in three places: `models.py`, `schema.sql`, `docs/database.md`.

### Commands (Windows PowerShell, run inside backend/)
```
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env          # then edit .env: SECRET_JWT, SEED_SUPERVISOR_PASSWORD, DATABASE_URL
python -m app.seed              # creates the tables (if missing) and the demo data
uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
python -m unittest discover tests -v
```
API docs: http://127.0.0.1:8000/docs

PostgreSQL: create an empty database, run `psql -d id_nurse -f schema.sql`, set
`DATABASE_URL=postgresql+psycopg://USER:PASSWORD@HOST:5432/id_nurse` in `.env`, then `python -m app.seed`.
Without PostgreSQL, the default `DATABASE_URL=sqlite:///id_nurse.db` makes a local file (delete it to start over).

If PowerShell blocks activating the venv, run once:
`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`

---

## Frontend (Flutter, in frontend/)

### Stack and target
- Flutter + Dart, target: Windows desktop (Android tablet later if time allows)
- Design screens to adapt to different sizes, so they also work on a tablet
- Packages: dio, provider, go_router, intl, shared_preferences
- English only, left-to-right layout. Font: IBM Plex Sans. `intl` for date/number formatting

### Layout
```
frontend/lib/
  screens/    one file per screen
  services/   ApiService interface, RealApiService (backend, default), MockApiService (fallback)
  models/     data classes matching docs/api.md
  widgets/    reusable widgets
  theme/      colors, fonts, spacing, taken from the Figma design
```

### Frontend rules
1. Match the Figma screens in `design/` closely: colors, fonts, spacing, layout.
2. Put all colors, fonts, and spacing in `lib/theme` so every screen stays consistent.
3. Screens never contain fake data and never call HTTP directly. They only call `ApiService`.
4. `MockApiService` must return data in exactly the shapes defined in docs/api.md
   (same field names, same order states). When the real API is connected, only the service class
   should change, not the screens.
5. The mock should behave like the real flow: an approved order goes PENDING -> DISPENSING -> DONE
   after a few seconds, so the demo looks realistic.
6. Keep the JWT in memory and send it as a Bearer token (real service only).
7. Order status screen polls every 1 to 2 seconds until the status is final (DONE, PARTIAL, or FAILED).
8. Run `flutter analyze` and `flutter test` before saying a task is done.
9. Every screen fits the window without scrolling and scales to the available height.

### Screens (in order of building)
1. Login (nurse: scan card or enter employee ID; supervisor: employee ID + password)
2. Patient file number (enter or scan)
3. Item selection with quantities and available stock
4. Order review and approval
5. Order status (preparing, collect/complete, partial result, failed)
6. Supervisor dashboard (stock, low stock, dispensing log, report export)

### Commands (run inside frontend/)
```
flutter pub get
flutter analyze
flutter test
flutter run -d windows                                  # uses the real backend
flutter run -d windows --dart-define=API_MODE=mock      # fake data, no backend needed
```
Other build settings: `--dart-define=API_BASE_URL=http://127.0.0.1:8000` (backend address, this is the default),
`--dart-define=DEMO_MODE=false` (hides the "Simulate card scan" button).
With the real backend there is no "Simulate robot fault" button (the backend has no fault endpoint).

---

## Running backend and frontend together
1. Terminal 1, inside `backend/` (first time: venv, `pip install`, `.env` and `python -m app.seed`, see above):
   `.venv\Scripts\activate` then `uvicorn app.main:app --host 127.0.0.1 --port 8000`
2. Check http://127.0.0.1:8000/health shows `{"status":"ok"}`.
3. Terminal 2, inside `frontend/`: `flutter run -d windows`
4. Sign in as nurse 48216 (scan or type the ID), patient 284913. Supervisor: 31082 with the password from
   `SEED_SUPERVISOR_PASSWORD`. The arm simulator fills the order in a few seconds (`ARM_SIM_STEP_SECONDS`).
If the app shows a connection error, the backend is not running or `API_BASE_URL` is wrong.
