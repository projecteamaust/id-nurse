"""Request and response shapes. Field names are exactly those in docs/api.md.

Only types are checked here; limits like "1 to 30 units" are checked in services.py,
so the error messages are the same ones the frontend's MockApiService uses.
"""

from typing import Literal

from pydantic import BaseModel, Field

Role = Literal["nurse", "supervisor"]
OrderStatus = Literal["PENDING", "DISPENSING", "DONE", "PARTIAL", "FAILED", "CANCELLED"]


class LoginRequest(BaseModel):
    employee_id: str = Field(min_length=1, max_length=50)
    method: Literal["scan", "manual"]
    password: str | None = Field(default=None, max_length=200)


class UserOut(BaseModel):
    id: int
    employee_id: str
    name: str
    role: Role
    ward: str


class LoginResponse(BaseModel):
    access_token: str
    token_type: str
    expires_in: int
    user: UserOut


class PersonRef(BaseModel):
    employee_id: str
    name: str


class PatientOut(BaseModel):
    id: int
    file_number: str
    name: str
    age: int
    room: str
    diagnosis_code: str


class ItemOut(BaseModel):
    id: int
    name: str
    sku: str
    category: str
    slot_number: int
    cabinet_location: str
    quantity: int
    min_quantity: int
    low_stock: bool


class LowStockItemOut(ItemOut):
    qty_to_minimum: int


class ItemQuantityUpdate(BaseModel):
    quantity: int


class OrderLineIn(BaseModel):
    item_id: int
    qty: int


class OrderCreate(BaseModel):
    patient_file_number: str = Field(min_length=1, max_length=20)
    items: list[OrderLineIn]


class OrderPatientRef(BaseModel):
    file_number: str
    name: str


class OrderItemOut(BaseModel):
    item_id: int
    name: str
    slot_number: int
    cabinet_location: str
    qty_requested: int
    qty_dispensed: int


class OrderOut(BaseModel):
    id: int
    status: OrderStatus
    patient: OrderPatientRef
    nurse: PersonRef
    created_at: str
    approved_at: str | None
    completed_at: str | None
    items: list[OrderItemOut]


class OrderSummaryOut(BaseModel):
    id: int
    status: OrderStatus
    patient_file_number: str
    nurse_name: str
    created_at: str
    item_count: int
    total_units: int


class ReportCreate(BaseModel):
    note: str | None = None


class MissingItem(BaseModel):
    item_id: int
    name: str
    slot_number: int
    qty_missing: int


class ProblemReportOut(BaseModel):
    id: int
    order_id: int
    status: Literal["open", "resolved"]
    note: str | None
    nurse: PersonRef
    missing_items: list[MissingItem]
    created_at: str
    resolved_at: str | None
    resolved_by: PersonRef | None


class AuditEntryOut(BaseModel):
    id: int
    timestamp: str
    actor: PersonRef | None
    action: str
    order_id: int | None
    summary: str
