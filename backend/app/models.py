import enum
import uuid
from datetime import datetime

from sqlalchemy import Boolean, Column, DateTime, Enum, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.db import Base


def gen_uuid() -> str:
    return str(uuid.uuid4())


class UserRole(str, enum.Enum):
    super_admin = "super_admin"
    academy_admin = "academy_admin"
    coach = "coach"
    student = "student"
    parent = "parent"


class AcademyStatus(str, enum.Enum):
    active = "active"
    suspended = "suspended"
    deleted = "deleted"


class AcademyCategory(str, enum.Enum):
    chess = "chess"
    other = "other"
    any = "any"


class Academy(Base):
    __tablename__ = "academies"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    name = Column(String, nullable=False)
    category = Column(Enum(AcademyCategory), default=AcademyCategory.any, nullable=False)
    logo_url = Column(String, nullable=True)
    address = Column(String, nullable=True)
    phone = Column(String, nullable=True)
    email = Column(String, nullable=True)
    tagline = Column(String, nullable=True)
    status = Column(Enum(AcademyStatus), default=AcademyStatus.active, nullable=False)
    created_by = Column(UUID(as_uuid=False), nullable=True)  # id of the super admin who created it
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    users = relationship("User", back_populates="academy")


class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    name = Column(String, nullable=False)
    email = Column(String, unique=True, nullable=False, index=True)
    phone = Column(String, nullable=True)
    hashed_password = Column(String, nullable=False)
    role = Column(Enum(UserRole), nullable=False)
    academy_id = Column(UUID(as_uuid=False), ForeignKey("academies.id"), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    academy = relationship("Academy", back_populates="users")


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    entity_type = Column(String, nullable=False)  # e.g. "academy"
    entity_id = Column(UUID(as_uuid=False), nullable=False)
    field_name = Column(String, nullable=False)
    old_value = Column(Text, nullable=True)
    new_value = Column(Text, nullable=True)
    changed_by = Column(UUID(as_uuid=False), ForeignKey("users.id"), nullable=False)
    changed_at = Column(DateTime, default=datetime.utcnow)


class Parent(Base):
    __tablename__ = "parents"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    academy_id = Column(UUID(as_uuid=False), ForeignKey("academies.id"), nullable=False)
    user_id = Column(UUID(as_uuid=False), ForeignKey("users.id"), nullable=True)
    name = Column(String, nullable=False)
    phone = Column(String, nullable=False)  # E.164, e.g. +919876543210
    alternate_phone = Column(String, nullable=True)
    email = Column(String, nullable=True)
    address = Column(String, nullable=True)

    students = relationship("Student", back_populates="parent")


class Student(Base):
    __tablename__ = "students"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    academy_id = Column(UUID(as_uuid=False), ForeignKey("academies.id"), nullable=False)
    parent_id = Column(UUID(as_uuid=False), ForeignKey("parents.id"), nullable=True)
    user_id = Column(UUID(as_uuid=False), ForeignKey("users.id"), nullable=True)
    batch_id = Column(UUID(as_uuid=False), ForeignKey("batches.id"), nullable=True)
    student_number = Column(Integer, nullable=True)  # academy-scoped, e.g. shown as PER-000143
    name = Column(String, nullable=False)
    photo_url = Column(String, nullable=True)
    date_of_birth = Column(DateTime, nullable=True)
    level = Column(String, nullable=True)
    current_rating = Column(Integer, default=0, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    default_fee = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    parent = relationship("Parent", back_populates="students")

    @property
    def parent_name(self):
        return self.parent.name if self.parent else None

    @property
    def parent_phone(self):
        return self.parent.phone if self.parent else None


class MessageType(str, enum.Enum):
    custom = "custom"
    payment_reminder = "payment_reminder"


class RecipientStatus(str, enum.Enum):
    pending = "pending"
    sent = "sent"
    failed = "failed"


class Broadcast(Base):
    """One WhatsApp send action - a trainer picks a message + a set of
    students, and this row represents that one action. Per-recipient
    outcome lives in BroadcastRecipient below."""

    __tablename__ = "broadcasts"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    academy_id = Column(UUID(as_uuid=False), ForeignKey("academies.id"), nullable=False)
    created_by = Column(UUID(as_uuid=False), ForeignKey("users.id"), nullable=False)
    message_type = Column(Enum(MessageType), default=MessageType.custom, nullable=False)
    body = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    recipients = relationship("BroadcastRecipient", back_populates="broadcast")


class BroadcastRecipient(Base):
    __tablename__ = "broadcast_recipients"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    broadcast_id = Column(UUID(as_uuid=False), ForeignKey("broadcasts.id"), nullable=False)
    student_id = Column(UUID(as_uuid=False), ForeignKey("students.id"), nullable=False)
    phone = Column(String, nullable=False)  # snapshotted at send time
    status = Column(Enum(RecipientStatus), default=RecipientStatus.pending, nullable=False)
    provider_message_id = Column(String, nullable=True)
    error_message = Column(Text, nullable=True)
    sent_at = Column(DateTime, nullable=True)

    broadcast = relationship("Broadcast", back_populates="recipients")


# ---- Batches, classes, attendance ----

class Batch(Base):
    __tablename__ = "batches"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    academy_id = Column(UUID(as_uuid=False), ForeignKey("academies.id"), nullable=False)
    coach_id = Column(UUID(as_uuid=False), ForeignKey("users.id"), nullable=True)
    name = Column(String, nullable=False)
    level = Column(String, nullable=True)
    schedule_days = Column(String, nullable=True)  # e.g. "Mon,Wed,Fri"
    start_time = Column(String, nullable=True)  # "18:30"
    end_time = Column(String, nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)


class AttendanceStatus(str, enum.Enum):
    present = "present"
    absent = "absent"


class ClassSession(Base):
    __tablename__ = "class_sessions"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    batch_id = Column(UUID(as_uuid=False), ForeignKey("batches.id"), nullable=False)
    topic = Column(String, nullable=True)
    scheduled_at = Column(DateTime, nullable=False)
    is_cancelled = Column(Boolean, default=False, nullable=False)
    cancellation_reason = Column(String, nullable=True)


class Attendance(Base):
    __tablename__ = "attendance"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    class_session_id = Column(UUID(as_uuid=False), ForeignKey("class_sessions.id"), nullable=False)
    student_id = Column(UUID(as_uuid=False), ForeignKey("students.id"), nullable=False)
    status = Column(Enum(AttendanceStatus), nullable=False)
    marked_by = Column(UUID(as_uuid=False), ForeignKey("users.id"), nullable=True)
    marked_at = Column(DateTime, default=datetime.utcnow)


# ---- Courses, lessons, assignments ----

class Course(Base):
    __tablename__ = "courses"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    academy_id = Column(UUID(as_uuid=False), ForeignKey("academies.id"), nullable=False)
    title = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    created_by = Column(UUID(as_uuid=False), nullable=True)


class Lesson(Base):
    __tablename__ = "lessons"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    course_id = Column(UUID(as_uuid=False), ForeignKey("courses.id"), nullable=False)
    title = Column(String, nullable=False)
    content_url = Column(String, nullable=True)
    order_index = Column(Integer, default=0, nullable=False)


class Assignment(Base):
    __tablename__ = "assignments"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    batch_id = Column(UUID(as_uuid=False), ForeignKey("batches.id"), nullable=True)
    lesson_id = Column(UUID(as_uuid=False), ForeignKey("lessons.id"), nullable=True)
    title = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    due_date = Column(DateTime, nullable=True)
    created_by = Column(UUID(as_uuid=False), nullable=True)


class AssignmentSubmission(Base):
    __tablename__ = "assignment_submissions"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    assignment_id = Column(UUID(as_uuid=False), ForeignKey("assignments.id"), nullable=False)
    student_id = Column(UUID(as_uuid=False), ForeignKey("students.id"), nullable=False)
    is_complete = Column(Boolean, default=False, nullable=False)
    submitted_at = Column(DateTime, nullable=True)


# ---- Puzzles ----

class Puzzle(Base):
    __tablename__ = "puzzles"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    academy_id = Column(UUID(as_uuid=False), ForeignKey("academies.id"), nullable=True)
    fen = Column(String, nullable=False)
    solution = Column(String, nullable=False)
    difficulty = Column(String, nullable=True)


class PuzzleAttempt(Base):
    __tablename__ = "puzzle_attempts"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    puzzle_id = Column(UUID(as_uuid=False), ForeignKey("puzzles.id"), nullable=False)
    student_id = Column(UUID(as_uuid=False), ForeignKey("students.id"), nullable=False)
    solved = Column(Boolean, nullable=False)
    attempted_at = Column(DateTime, default=datetime.utcnow)


# ---- Games ----

class GameResult(str, enum.Enum):
    win = "win"
    loss = "loss"
    draw = "draw"


class Game(Base):
    __tablename__ = "games"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    student_id = Column(UUID(as_uuid=False), ForeignKey("students.id"), nullable=False)
    opponent_name = Column(String, nullable=True)
    pgn = Column(Text, nullable=True)
    result = Column(Enum(GameResult), nullable=True)
    played_at = Column(DateTime, default=datetime.utcnow)


class GameReview(Base):
    __tablename__ = "game_reviews"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    game_id = Column(UUID(as_uuid=False), ForeignKey("games.id"), nullable=False)
    coach_id = Column(UUID(as_uuid=False), ForeignKey("users.id"), nullable=False)
    comments = Column(Text, nullable=True)
    reviewed_at = Column(DateTime, default=datetime.utcnow)


class RatingHistory(Base):
    __tablename__ = "rating_history"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    student_id = Column(UUID(as_uuid=False), ForeignKey("students.id"), nullable=False)
    rating = Column(Integer, nullable=False)
    recorded_at = Column(DateTime, default=datetime.utcnow)
    note = Column(String, nullable=True)


# ---- Tournaments ----

class TournamentType(str, enum.Enum):
    in_house = "in_house"
    third_party = "third_party"


class Tournament(Base):
    __tablename__ = "tournaments"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    academy_id = Column(UUID(as_uuid=False), ForeignKey("academies.id"), nullable=False)
    name = Column(String, nullable=False)
    organizer_name = Column(String, nullable=True)
    tournament_type = Column(Enum(TournamentType), default=TournamentType.in_house, nullable=False)
    start_date = Column(DateTime, nullable=True)
    end_date = Column(DateTime, nullable=True)
    reporting_time = Column(DateTime, nullable=True)
    venue = Column(String, nullable=True)
    fee_amount = Column(Integer, nullable=True)
    sports = Column(String, default="Chess", nullable=False)
    category = Column(String, default="1 Category", nullable=False)
    status = Column(String, default="open", nullable=False) # open or completed
    result_url = Column(String, nullable=True)
    notes = Column(Text, nullable=True)
    banner_url = Column(String, nullable=True)
    brochure_url = Column(String, nullable=True)


class TournamentRegistration(Base):
    __tablename__ = "tournament_registrations"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    tournament_id = Column(UUID(as_uuid=False), ForeignKey("tournaments.id"), nullable=False)
    student_id = Column(UUID(as_uuid=False), ForeignKey("students.id"), nullable=False)
    registered_at = Column(DateTime, default=datetime.utcnow)


# ---- Payments ----

class PlanType(str, enum.Enum):
    monthly = "monthly"
    quarterly = "quarterly"
    yearly = "yearly"


class PaymentStatus(str, enum.Enum):
    unpaid = "unpaid"
    partial = "partial"
    paid = "paid"


class Payment(Base):
    """No payment gateway - the academy manager sets status by hand
    (cash, bank transfer, whatever happened outside the app). This is a
    monitoring/tracking record, not a transaction."""

    __tablename__ = "payments"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    student_id = Column(UUID(as_uuid=False), ForeignKey("students.id"), nullable=False)
    plan_type = Column(Enum(PlanType), nullable=False)
    amount = Column(Integer, nullable=False)  # total due
    amount_paid = Column(Integer, default=0, nullable=False)  # running total, for "partial"
    status = Column(Enum(PaymentStatus), default=PaymentStatus.unpaid, nullable=False)
    due_date = Column(DateTime, nullable=True)
    paid_at = Column(DateTime, nullable=True)  # set the moment status first reaches "paid"
    invoice_number = Column(String, nullable=True)


# ---- Platform Billing (Super Admin to Academies) ----

class PlatformInvoiceStatus(str, enum.Enum):
    uncleared = "uncleared"
    cleared = "cleared"


class PlatformInvoice(Base):
    __tablename__ = "platform_invoices"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    academy_id = Column(UUID(as_uuid=False), ForeignKey("academies.id"), nullable=False)
    amount = Column(Integer, nullable=False)
    status = Column(Enum(PlatformInvoiceStatus), default=PlatformInvoiceStatus.uncleared, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    cleared_at = Column(DateTime, nullable=True)
    due_date = Column(DateTime, nullable=True)
    notes = Column(Text, nullable=True)
    
    academy = relationship("Academy")



# ---- Notifications ----

class NotificationType(str, enum.Enum):
    class_reminder = "class_reminder"
    class_cancelled = "class_cancelled"
    tournament = "tournament"
    fee_due = "fee_due"
    new_assignment = "new_assignment"
    new_lesson = "new_lesson"
    tournament_result = "tournament_result"
    achievement = "achievement"
    platform_fee_due = "platform_fee_due"
    platform_fee_receipt = "platform_fee_receipt"


class Notification(Base):
    __tablename__ = "notifications"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    recipient_user_id = Column(UUID(as_uuid=False), ForeignKey("users.id"), nullable=False)
    type = Column(Enum(NotificationType), nullable=False)
    title = Column(String, nullable=False)
    body = Column(Text, nullable=True)
    is_read = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)


# ---- Calendar / holidays ----

class Holiday(Base):
    __tablename__ = "holidays"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    academy_id = Column(UUID(as_uuid=False), ForeignKey("academies.id"), nullable=False)
    date = Column(DateTime, nullable=False)  # stored at midnight, one row per day
    reason = Column(String, nullable=True)


class ExpenseType(str, enum.Enum):
    investment = "investment"
    expense = "expense"
    other = "other"


class Expense(Base):
    __tablename__ = "expenses"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    academy_id = Column(UUID(as_uuid=False), ForeignKey("academies.id"), nullable=False)
    created_by = Column(UUID(as_uuid=False), ForeignKey("users.id"), nullable=False)
    amount = Column(Integer, nullable=False)
    description = Column(String, nullable=False)
    expense_type = Column(Enum(ExpenseType), default=ExpenseType.expense, nullable=False)
    expense_date = Column(DateTime, default=datetime.utcnow, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)


# ---- Materials & Inventory ----

class Material(Base):
    __tablename__ = "materials"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    academy_id = Column(UUID(as_uuid=False), ForeignKey("academies.id"), nullable=False)
    name = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    price = Column(Integer, nullable=False)
    stock_quantity = Column(Integer, default=0, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)


class MaterialSale(Base):
    __tablename__ = "material_sales"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    material_id = Column(UUID(as_uuid=False), ForeignKey("materials.id"), nullable=False)
    student_id = Column(UUID(as_uuid=False), ForeignKey("students.id"), nullable=True)
    quantity = Column(Integer, nullable=False)
    total_price = Column(Integer, nullable=False)
    sold_at = Column(DateTime, default=datetime.utcnow)

