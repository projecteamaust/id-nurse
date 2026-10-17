# ID Nurse

Graduation project: a smart system for managing and dispensing non-pharmaceutical medical supplies.
A nurse enters a patient file number, picks items and quantities, approves the order, and a robot arm
picks the items from a cabinet into a pickup box. Every action is logged for auditing and insurance claims.

Two parts in one repo:
- Backend (Python/FastAPI) in `app/`
- Frontend (Flutter) in `frontend/`

Detailed specs live in `docs/`. Read the relevant file before working on that area:
- `docs/database.md`: tables and columns
- `docs/api.md`: endpoints, roles, order states (the contract between frontend and backend)
- `docs/order-flow-and-arm.md`: order flow, ArmController, Serial protocol
- `docs/prototype-review.md`: every prototype screen with its text, colors, fonts, actions and API calls
- `design/prototype/`: Figma prototype code (`src/App.tsx` screens, `src/index.css` colors/fonts)

## Current build order
1. Tiny backend skeleton with /health (so the project runs and the API contract exists)
2. Flutter frontend, screen by screen, using MockApiService (fake data)
3. Real backend: database + seed, login, orders, dispensing with MockArm
4. Connect the Flutter screens to the real API (replace MockApiService)
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

## Backend (Python, in app/)

### Stack
- Python 3.10+, FastAPI, Uvicorn, Pydantic
- SQLite via the built-in `sqlite3` module (NO ORM). WAL mode and foreign keys ON
- PyJWT for tokens, `hashlib` PBKDF2 (200,000 iterations) for passwords
- pyserial (real arm only), openpyxl and reportlab (reports, later phase)
- Tests: built-in `unittest`

### Layout
```
app/
  config.py     all settings from environment variables
  db.py         schema + connection
  security.py   password hashing, JWT
  arm.py        ArmController interface, MockArm, RealArm
  services.py   ALL business logic (must NOT import FastAPI)
  main.py       thin API routes + role checks; only calls services
  seed.py       demo data: 2 users, 2 patients, 6 items
static/          calibrate.html (supervisor arm calibration page)
firmware/arm_controller/   Arduino sketch (later)
tests/           unittest files
docs/            specs
design/          Figma prototype (design/prototype/)
frontend/        Flutter app
```

### Backend rules
1. Business logic goes in `services.py`; routes in `main.py` stay thin.
2. Never store or log plain-text passwords. Secrets come from env (`SECRET_JWT`), never hardcoded.
3. Stock decreases ONLY after a successful physical pick, never at order creation.
4. Every important action writes to `audit_log`: login success/failure, order create/approve/cancel,
   pick results, stock edits, pose saves.
5. Roles: `nurse` and `supervisor`. A nurse can approve/cancel only her own orders; a supervisor can do anything.
6. Default arm mode is `mock`. The real arm is selected by config, never by editing code.
7. Server runs on 127.0.0.1 only.
8. Every new backend feature comes with tests.
9. Do not rename or remove endpoints or fields in docs/api.md without asking (frontend depends on them).

### Commands (Windows PowerShell)
```
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python -m app.seed
uvicorn app.main:app --reload
python -m unittest discover tests -v
```
API docs: http://127.0.0.1:8000/docs

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
  services/   ApiService interface, MockApiService, (later) RealApiService
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
flutter run -d windows
```
