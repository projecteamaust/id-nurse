"""API routes. Thin: check who is calling and their role, then call services.py.

Run from the backend/ folder:   uvicorn app.main:app --host 127.0.0.1 --port 8000
API docs: http://127.0.0.1:8000/docs
"""

from contextlib import asynccontextmanager
from datetime import date
from typing import Literal

from fastapi import Depends, FastAPI, Query, Request, Response
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from . import db, services
from .models import User
from .schemas import (
    AuditEntryOut, ItemOut, ItemQuantityUpdate, LoginRequest, LoginResponse, LowStockItemOut, OrderCreate,
    OrderOut, OrderStatus, OrderSummaryOut, PatientOut, ProblemReportOut, ReportCreate, Role, UserOut,
)

bearer = HTTPBearer(auto_error=False)


# ---------------------------------------------------------------- who is calling


def get_session():
    with db.session_scope() as session:
        yield session


def current_user(credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
                 session: Session = Depends(get_session)) -> User:
    return services.user_from_token(session, credentials.credentials if credentials else None)


def supervisor(user: User = Depends(current_user)) -> User:
    if user.role != "supervisor":
        raise services.Forbidden("Supervisors only")
    return user


# ---------------------------------------------------------------- errors as {"detail": "message"}


def _service_error(_request: Request, error: services.ServiceError) -> JSONResponse:
    return JSONResponse({"detail": error.detail}, status_code=error.status_code)


def _validation_error(_request: Request, error: RequestValidationError) -> JSONResponse:
    """One short message instead of FastAPI's list, so every error has the same shape."""
    first = error.errors()[0] if error.errors() else {}
    where = ".".join(str(part) for part in first.get("loc", ()) if part not in ("body", "query", "path"))
    message = first.get("msg", "Invalid input")
    return JSONResponse({"detail": f"{where}: {message}" if where else message}, status_code=422)


# ---------------------------------------------------------------- app


def create_app(start_worker: bool = True) -> FastAPI:
    """start_worker=False is for tests: they run the arm worker step by step themselves."""

    @asynccontextmanager
    async def lifespan(_app: FastAPI):
        worker = None
        if start_worker:
            from .worker import create_worker

            worker = create_worker()
            worker.start()
        yield
        if worker:
            worker.stop()

    app = FastAPI(title="ID Nurse API", version="1.0.0", lifespan=lifespan)
    app.add_exception_handler(services.ServiceError, _service_error)
    app.add_exception_handler(RequestValidationError, _validation_error)

    @app.get("/health")
    def health() -> dict:
        return {"status": "ok"}

    # ---- auth

    @app.post("/auth/login", response_model=LoginResponse)
    def login(body: LoginRequest, session: Session = Depends(get_session)):
        return services.login(session, body.employee_id, body.method, body.password)

    @app.get("/me", response_model=UserOut)
    def me(user: User = Depends(current_user)):
        return services.user_json(user)

    @app.get("/users", response_model=list[UserOut])
    def users(role: Role | None = None, _: User = Depends(supervisor), session: Session = Depends(get_session)):
        return services.list_users(session, role)

    # ---- patients and items

    @app.get("/patients/{file_number}", response_model=PatientOut)
    def patient(file_number: str, _: User = Depends(current_user), session: Session = Depends(get_session)):
        return services.get_patient(session, file_number)

    @app.get("/items", response_model=list[ItemOut])
    def items(category: str | None = None, search: str | None = None,
              _: User = Depends(current_user), session: Session = Depends(get_session)):
        return services.list_items(session, category, search)

    @app.patch("/items/{item_id}", response_model=ItemOut)
    def edit_item(item_id: int, body: ItemQuantityUpdate,
                  user: User = Depends(supervisor), session: Session = Depends(get_session)):
        return services.update_item_quantity(session, user, item_id, body.quantity)

    # ---- orders

    @app.post("/orders", response_model=OrderOut, status_code=201)
    def create_order(body: OrderCreate, user: User = Depends(current_user), session: Session = Depends(get_session)):
        lines = [(line.item_id, line.qty) for line in body.items]
        return services.create_order(session, user, body.patient_file_number, lines)

    @app.post("/orders/{order_id}/approve", response_model=OrderOut)
    def approve(order_id: int, user: User = Depends(current_user), session: Session = Depends(get_session)):
        return services.approve_order(session, user, order_id)

    @app.post("/orders/{order_id}/cancel", response_model=OrderOut)
    def cancel(order_id: int, user: User = Depends(current_user), session: Session = Depends(get_session)):
        return services.cancel_order(session, user, order_id)

    @app.get("/orders/{order_id}", response_model=OrderOut)
    def order(order_id: int, user: User = Depends(current_user), session: Session = Depends(get_session)):
        return services.get_order(session, user, order_id)

    @app.get("/orders", response_model=list[OrderSummaryOut])
    def orders(limit: int = 20, nurse_id: int | None = None, status: OrderStatus | None = None,
               date_from: date | None = Query(None, alias="from"), date_to: date | None = Query(None, alias="to"),
               user: User = Depends(current_user), session: Session = Depends(get_session)):
        return services.list_orders(session, user, limit, nurse_id, status, date_from, date_to)

    # ---- problem reports

    @app.post("/orders/{order_id}/report", response_model=ProblemReportOut, status_code=201)
    def report_problem(order_id: int, body: ReportCreate | None = None,
                       user: User = Depends(current_user), session: Session = Depends(get_session)):
        return services.report_problem(session, user, order_id, body.note if body else None)

    @app.get("/problem-reports", response_model=list[ProblemReportOut])
    def problem_reports(status: Literal["open", "resolved", "all"] = "open",
                        _: User = Depends(supervisor), session: Session = Depends(get_session)):
        return services.list_problem_reports(session, status)

    @app.post("/problem-reports/{report_id}/resolve", response_model=ProblemReportOut)
    def resolve_report(report_id: int, user: User = Depends(supervisor), session: Session = Depends(get_session)):
        return services.resolve_problem_report(session, user, report_id)

    # ---- reports for the supervisor dashboard

    @app.get("/reports/low-stock", response_model=list[LowStockItemOut])
    def low_stock(_: User = Depends(supervisor), session: Session = Depends(get_session)):
        return services.low_stock(session)

    @app.get("/audit", response_model=list[AuditEntryOut])
    def audit(limit: int = 100, nurse_id: int | None = None,
              date_from: date | None = Query(None, alias="from"), date_to: date | None = Query(None, alias="to"),
              _: User = Depends(supervisor), session: Session = Depends(get_session)):
        return services.list_audit(session, limit, nurse_id, date_from, date_to)

    @app.get("/reports/dispense.csv")
    def dispense_csv(nurse_id: int | None = None,
                     date_from: date | None = Query(None, alias="from"), date_to: date | None = Query(None, alias="to"),
                     _: User = Depends(supervisor), session: Session = Depends(get_session)):
        text = services.dispense_csv(session, nurse_id, date_from, date_to)
        return Response(text, media_type="text/csv; charset=utf-8",
                        headers={"Content-Disposition": 'attachment; filename="dispense-report.csv"'})

    return app


app = create_app()
