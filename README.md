# ID Nurse

Graduation project: a smart system for managing and dispensing non-pharmaceutical medical supplies.

A nurse enters a patient file number, picks items and quantities, and approves the order. A robot arm then picks the items from a cabinet into a pickup box. Every action is logged for auditing and insurance claims.

## Project structure

```
backend/    Python / FastAPI API (SQLite for the demo, PostgreSQL optional)
frontend/   Flutter app (Windows desktop)
docs/       Detailed specs (database, API, order flow and arm)
design/     Figma prototype code
```

## Requirements

- Python 3.10 or newer
- Flutter (with Windows desktop support enabled)
- Git
- PostgreSQL is **optional**. The demo runs on SQLite by default.

## First-time setup

### 1. Get the code

Clone the repo (or use GitHub Desktop) and switch to the `main` branch, then pull the latest changes.

### 2. Backend

Open PowerShell and run these commands one by one, inside the `backend` folder:

```powershell
cd backend
python -m venv .venv
.venv\Scripts\activate
python -m pip install -r requirements.txt
copy .env.example .env
```

After `activate`, you should see `(.venv)` at the start of the line.

Open `.env` (for example `notepad .env`) and set:

| Variable | What to write |
|---|---|
| `SECRET_JWT` | Any long random text. Generate one with `python -c "import secrets; print(secrets.token_hex(32))"` |
| `SEED_SUPERVISOR_PASSWORD` | Any password you choose. It is the supervisor's login password. |
| `DATABASE_URL` | Leave the default (`sqlite:///id_nurse.db`) for the demo. |

Never commit `.env`. Every team member creates their own.

Create the demo data:

```powershell
python -m app.seed
```

You should see: `Demo data added. Nurse: 48216. Supervisor: 31082.`

### 3. Frontend

In a **second** PowerShell tab, inside the `frontend` folder:

```powershell
cd frontend
flutter pub get
```

## Running the project

You need two terminals open at the same time.

**Terminal 1: backend** (inside `backend`, with `(.venv)` active)

```powershell
.venv\Scripts\activate
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

Check it works by opening http://127.0.0.1:8000/health. It should show `{"status":"ok"}`.
All endpoints are listed at http://127.0.0.1:8000/docs.

**Terminal 2: frontend** (inside `frontend`)

```powershell
flutter run -d windows
```

Keep the backend running while you use the app.

## Demo logins

| Role | Employee ID | Password |
|---|---|---|
| Nurse | `48216` | none (type the ID or use "Simulate card scan") |
| Supervisor | `31082` | the value of `SEED_SUPERVISOR_PASSWORD` in your `.env` |

Demo patient file number: `284913`

The robot arm is simulated by default, so an approved order fills in a few seconds.

## Useful options

Run the frontend with fake data, no backend needed:

```powershell
flutter run -d windows --dart-define=API_MODE=mock
```

Point the frontend to a different backend address:

```powershell
flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

## Tests

```powershell
# backend (inside backend/, venv active)
python -m unittest discover tests -v

# frontend (inside frontend/)
flutter analyze
flutter test
```

## Using PostgreSQL (optional)

1. Create an empty database named `id_nurse`.
2. Run `psql -d id_nurse -f schema.sql` inside `backend/`.
3. In `.env`, set `DATABASE_URL=postgresql+psycopg://USER:PASSWORD@HOST:5432/id_nurse`.
4. Run `python -m app.seed`.

## Troubleshooting

**`uvicorn` is not recognized, or `No module named sqlalchemy`**
The virtual environment is not active or the packages are not installed. Run `.venv\Scripts\activate`, then `python -m pip install -r requirements.txt`.

**PowerShell blocks `activate` (execution policy error)**
Run once: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`

**Error 10048: address already in use (port 8000)**
Another server is already running on port 8000. Find and stop it:

```powershell
netstat -ano | findstr :8000
taskkill /PID <process_id> /F
```

**`{"detail":"Not Found"}` in the browser**
The server is running, but the path is wrong. Open `/health` or `/docs`.

**Supervisor login says invalid credentials**
You changed the password in `.env` after running the seed. Stop the server, delete the database, and seed again:

```powershell
del id_nurse.db
python -m app.seed
```

**The app shows a connection error**
The backend is not running, or `API_BASE_URL` is wrong.

## Known limitation

With ID-only nurse login, anyone who knows a nurse's employee ID can sign in as that nurse. This is accepted for the prototype. A future fix is a PIN or an encrypted badge.
