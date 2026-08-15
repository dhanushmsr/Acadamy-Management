from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, ConfigDict, EmailStr

from app.models import AcademyStatus, AcademyCategory, MessageType, PlanType, PaymentStatus, PlatformInvoiceStatus, RecipientStatus, UserRole, TournamentType


# ---- Auth ----

class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class PasswordResetPayload(BaseModel):
    new_password: str


class AuthTokens(BaseModel):
    access_token: str
    token_type: str = "bearer"


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: UserRole
    academy_id: Optional[str] = None


# ---- Academy ----

class AcademyCreate(BaseModel):
    name: str
    category: AcademyCategory = AcademyCategory.any
    address: Optional[str] = None
    logo_url: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    tagline: Optional[str] = None
    admin_name: str
    admin_email: EmailStr
    admin_password: str


class AcademyUpdate(BaseModel):
    name: Optional[str] = None
    category: Optional[AcademyCategory] = None
    address: Optional[str] = None
    logo_url: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    tagline: Optional[str] = None


class AcademyOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    category: AcademyCategory
    address: Optional[str]
    logo_url: Optional[str]
    phone: Optional[str] = None
    email: Optional[str] = None
    tagline: Optional[str] = None
    status: AcademyStatus
    created_at: datetime
    student_count: int = 0  # populated by the super-admin list endpoint, not stored


class AcademyCreatedOut(AcademyOut):
    pass


# ---- User ----

class UserCreate(BaseModel):
    name: str
    email: EmailStr
    role: UserRole
    academy_id: Optional[str] = None


class UserUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    password: Optional[str] = None


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
    default_fee: Optional[int] = None
    # Either links to an existing parent by phone, or creates a new one
    parent_name: Optional[str] = None
    parent_phone: Optional[str] = None
    parent_alternate_phone: Optional[str] = None
    parent_email: Optional[str] = None
    parent_address: Optional[str] = None


class StudentUpdate(BaseModel):
    name: Optional[str] = None
    date_of_birth: Optional[datetime] = None
    level: Optional[str] = None
    batch_id: Optional[str] = None
    is_active: Optional[bool] = None
    default_fee: Optional[int] = None
    parent_name: Optional[str] = None
    parent_phone: Optional[str] = None
    parent_email: Optional[str] = None
    parent_address: Optional[str] = None


class StudentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    student_number: Optional[int] = None
    name: str
    date_of_birth: Optional[datetime] = None
    level: Optional[str] = None
    batch_id: Optional[str] = None
    batch_name: Optional[str] = None
    is_active: bool = True
    default_fee: Optional[int] = None
    parent_name: Optional[str] = None
    parent_phone: Optional[str] = None
    parent_email: Optional[str] = None
    parent_address: Optional[str] = None


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


# ---- Platform Billing ----

class PlatformInvoiceCreate(BaseModel):
    academy_id: str
    amount: int
    due_date: Optional[datetime] = None
    notes: Optional[str] = None


class PlatformInvoiceStatusUpdate(BaseModel):
    status: PlatformInvoiceStatus


class PlatformInvoiceOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    academy_id: str
    amount: int
    status: PlatformInvoiceStatus
    created_at: datetime
    cleared_at: Optional[datetime] = None
    due_date: Optional[datetime] = None
    notes: Optional[str] = None
    academy_name: Optional[str] = None


# ---- Notifications ----

class NotificationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id: str
    type: str
    title: str
    body: Optional[str] = None
    is_read: bool
    created_at: datetime


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


# ---- Expenses ----

class ExpenseCreate(BaseModel):
    amount: int
    description: str
    expense_type: str
    expense_date: Optional[datetime] = None


class ExpenseOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    amount: int
    description: str
    expense_type: str
    expense_date: datetime
    created_at: datetime


# ---- Tournaments ----

class TournamentCreate(BaseModel):
    name: str
    organizer_name: Optional[str] = None
    organizer_phone: Optional[str] = None
    organizer_email: Optional[str] = None
    tournament_type: TournamentType = TournamentType.in_house
    sports: Optional[str] = "Chess"
    category: Optional[str] = "Open"
    status: Optional[str] = "open"
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    reporting_time: Optional[datetime] = None
    venue: Optional[str] = None
    city_or_place: Optional[str] = None
    fee_amount: Optional[int] = 0
    notes: Optional[str] = None
    rules_and_prizes: Optional[str] = None
    result_url: Optional[str] = None
    banner_url: Optional[str] = None
    brochure_url: Optional[str] = None


class TournamentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    academy_id: str
    name: str
    organizer_name: Optional[str] = None
    organizer_phone: Optional[str] = None
    organizer_email: Optional[str] = None
    tournament_type: TournamentType
    sports: str = "Chess"
    category: str = "Open"
    status: str = "open"
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    reporting_time: Optional[datetime] = None
    venue: Optional[str] = None
    city_or_place: Optional[str] = None
    fee_amount: Optional[int] = 0
    notes: Optional[str] = None
    rules_and_prizes: Optional[str] = None
    result_url: Optional[str] = None
    banner_url: Optional[str] = None
    brochure_url: Optional[str] = None
    created_at: Optional[datetime] = None
    participant_count: int = 0
    total_collected: int = 0


class PublicTournamentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    academy_id: str
    academy_name: str
    academy_logo: Optional[str] = None
    academy_phone: Optional[str] = None
    academy_email: Optional[str] = None
    academy_tagline: Optional[str] = None
    name: str
    organizer_name: Optional[str] = None
    organizer_phone: Optional[str] = None
    organizer_email: Optional[str] = None
    sports: str = "Chess"
    category: str = "Open"
    status: str = "open"
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    reporting_time: Optional[datetime] = None
    venue: Optional[str] = None
    city_or_place: Optional[str] = None
    fee_amount: Optional[int] = 0
    notes: Optional[str] = None
    rules_and_prizes: Optional[str] = None
    result_url: Optional[str] = None
    banner_url: Optional[str] = None
    brochure_url: Optional[str] = None
    is_expired: bool = False
    participant_count: int = 0


class TournamentRegistrationCreate(BaseModel):
    student_id: Optional[str] = None
    participant_name: str
    participant_phone: str
    participant_email: str
    participant_dob: Optional[datetime] = None


class TournamentRegistrationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id: str
    tournament_id: str
    student_id: Optional[str] = None
    participant_name: Optional[str] = None
    participant_phone: Optional[str] = None
    participant_email: Optional[str] = None
    payment_status: str = "paid"
    razorpay_order_id: Optional[str] = None
    razorpay_payment_id: Optional[str] = None
    amount_paid: int = 0
    registered_at: datetime


class RazorpayOrderRequest(BaseModel):
    participant_name: str
    participant_phone: str
    participant_email: str
    participant_dob: Optional[datetime] = None
    student_id: Optional[str] = None


class RazorpayOrderResponse(BaseModel):
    order_id: str
    key_id: str
    amount: int
    currency: str = "INR"
    registration_id: str
    tournament_name: str


class RazorpayVerifyRequest(BaseModel):
    registration_id: str
    razorpay_order_id: str
    razorpay_payment_id: str
    razorpay_signature: Optional[str] = None


# ---- Materials & Inventory ----

class MaterialCreate(BaseModel):
    name: str
    description: Optional[str] = None
    price: int
    stock_quantity: int = 0


class MaterialOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    academy_id: str
    name: str
    description: Optional[str] = None
    price: int
    stock_quantity: int
    created_at: datetime


class MaterialSaleCreate(BaseModel):
    material_id: str
    student_id: Optional[str] = None
    quantity: int


class MaterialSaleOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    material_id: str
    student_id: Optional[str] = None
    quantity: int
    total_price: int
    sold_at: datetime


# ---- Reports ----

class ReportSummary(BaseModel):
    total_students: int
    total_revenue: int
    total_expenses: int
    net_profit: int
    average_attendance_percentage: float


