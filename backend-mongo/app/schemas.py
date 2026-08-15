from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, ConfigDict, EmailStr

from app.models import AcademyStatus, MessageType, PlanType, PaymentStatus, RecipientStatus, UserRole


# ---- Auth ----

class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: UserRole
    academy_id: Optional[str] = None


# ---- Academy ----

class AcademyCreate(BaseModel):
    name: str
    address: Optional[str] = None
    logo_url: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    tagline: Optional[str] = None
    admin_name: str
    admin_email: EmailStr


class AcademyUpdate(BaseModel):
    name: Optional[str] = None
    address: Optional[str] = None
    logo_url: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    tagline: Optional[str] = None


class AcademyOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    address: Optional[str]
    logo_url: Optional[str]
    phone: Optional[str] = None
    email: Optional[str] = None
    tagline: Optional[str] = None
    status: AcademyStatus
    created_at: datetime
    student_count: int = 0  # populated by the super-admin list endpoint, not stored


class AcademyCreatedOut(AcademyOut):
    """Only returned once, from POST /academies - the temp password
    exists nowhere else after this (it's hashed before storage), so
    this is the one moment the Super Admin can see and hand it off."""

    admin_temp_password: str


# ---- User ----

class UserCreate(BaseModel):
    name: str
    email: EmailStr
    role: UserRole
    academy_id: Optional[str] = None


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    email: EmailStr
    phone: Optional[str] = None
    role: UserRole
    academy_id: Optional[str]
    is_active: bool


# ---- Team (academy admin creating their own coaches) ----

class CoachCreate(BaseModel):
    name: str
    email: EmailStr


# ---- Students (full CRUD) ----

class StudentCreate(BaseModel):
    name: str
    date_of_birth: Optional[datetime] = None
    level: Optional[str] = None
    batch_id: Optional[str] = None
    # Either links to an existing parent by phone, or creates a new one
    parent_name: Optional[str] = None
    parent_phone: Optional[str] = None
    parent_alternate_phone: Optional[str] = None
    parent_email: Optional[str] = None
    parent_address: Optional[str] = None


class StudentUpdate(BaseModel):
    name: Optional[str] = None
    level: Optional[str] = None
    batch_id: Optional[str] = None
    is_active: Optional[bool] = None


class StudentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    student_number: Optional[int] = None
    name: str
    level: Optional[str] = None
    batch_id: Optional[str] = None
    is_active: bool = True
    parent_name: Optional[str] = None
    parent_phone: Optional[str] = None
    parent_email: Optional[str] = None


# ---- Batches ----

class BatchCreate(BaseModel):
    name: str
    level: Optional[str] = None
    schedule_days: Optional[str] = None
    start_time: Optional[str] = None
    end_time: Optional[str] = None


class BatchOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    level: Optional[str] = None
    schedule_days: Optional[str] = None
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    is_active: bool


# ---- Payments (no gateway - manager-entered status) ----

class PaymentCreate(BaseModel):
    student_id: str
    plan_type: PlanType
    amount: int
    due_date: Optional[datetime] = None


class PaymentStatusUpdate(BaseModel):
    status: PaymentStatus  # "unpaid" / "partial" / "paid"
    amount_paid: Optional[int] = None  # meaningful for "partial"; ignored for the other two


class PaymentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    student_id: str
    student_name: Optional[str] = None
    plan_type: PlanType
    amount: int
    amount_paid: int = 0
    status: PaymentStatus
    due_date: Optional[datetime] = None
    paid_at: Optional[datetime] = None
    invoice_number: Optional[str] = None


# ---- Messaging (WhatsApp) ----

class BroadcastCreate(BaseModel):
    message_type: MessageType = MessageType.custom
    body: str
    student_ids: Optional[List[str]] = None
    send_to_all: bool = False


class BroadcastOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    message_type: MessageType
    body: str
    created_at: datetime


class BroadcastRecipientOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    student_id: str
    phone: str
    status: RecipientStatus
    error_message: Optional[str] = None
    sent_at: Optional[datetime] = None


class BroadcastDetailOut(BroadcastOut):
    recipients: List[BroadcastRecipientOut] = []
