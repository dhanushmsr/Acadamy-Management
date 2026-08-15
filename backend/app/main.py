from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os

from app.db import Base, engine
from app.routers import (
    academies,
    attendance,
    audit,
    auth,
    batches,
    messages,
    payments,
    students,
    team,
    users,
    platform_billing,
    notifications,
    dashboard,
    expenses,
    tournaments,
    materials,
    reports,
)

from sqlalchemy import text

# For local/dev use only. Replace with Alembic migrations before production.
Base.metadata.create_all(bind=engine)

def _run_auto_migrations():
    statements = [
        "ALTER TABLE tournaments ADD COLUMN IF NOT EXISTS organizer_phone VARCHAR;",
        "ALTER TABLE tournaments ADD COLUMN IF NOT EXISTS organizer_email VARCHAR;",
        "ALTER TABLE tournaments ADD COLUMN IF NOT EXISTS city_or_place VARCHAR;",
        "ALTER TABLE tournaments ADD COLUMN IF NOT EXISTS rules_and_prizes TEXT;",
        "ALTER TABLE tournaments ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;",
        "ALTER TABLE tournament_registrations ALTER COLUMN student_id DROP NOT NULL;",
        "ALTER TABLE tournament_registrations ADD COLUMN IF NOT EXISTS participant_name VARCHAR;",
        "ALTER TABLE tournament_registrations ADD COLUMN IF NOT EXISTS participant_phone VARCHAR;",
        "ALTER TABLE tournament_registrations ADD COLUMN IF NOT EXISTS participant_email VARCHAR;",
        "ALTER TABLE tournament_registrations ADD COLUMN IF NOT EXISTS participant_dob TIMESTAMP;",
        "ALTER TABLE tournament_registrations ADD COLUMN IF NOT EXISTS payment_status VARCHAR DEFAULT 'paid';",
        "ALTER TABLE tournament_registrations ADD COLUMN IF NOT EXISTS razorpay_order_id VARCHAR;",
        "ALTER TABLE tournament_registrations ADD COLUMN IF NOT EXISTS razorpay_payment_id VARCHAR;",
        "ALTER TABLE tournament_registrations ADD COLUMN IF NOT EXISTS amount_paid INTEGER DEFAULT 0;",
        "ALTER TABLE payments ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;",
    ]
    for stmt in statements:
        try:
            with engine.begin() as conn:
                conn.execute(text(stmt))
        except Exception as ex:
            print(f"Migration statement skipped: {ex}")

_run_auto_migrations()

os.makedirs("static/logos", exist_ok=True)

app = FastAPI(title="AcD-Man API")

app.mount("/static", StaticFiles(directory="static"), name="static")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # tighten this to your real domains before production
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(academies.router)
app.include_router(users.router)
app.include_router(tournaments.router)
app.include_router(materials.router)
app.include_router(reports.router)
app.include_router(students.router)
app.include_router(messages.router)
app.include_router(batches.router)
app.include_router(team.router)
app.include_router(payments.router)
app.include_router(attendance.router)
app.include_router(audit.router)
app.include_router(platform_billing.router)
app.include_router(notifications.router)
app.include_router(dashboard.router)
app.include_router(expenses.router)


@app.get("/")
def root():
    return {"status": "ok", "message": "AcD-Man API is running"}


@app.get("/health")
def health():
    return {"status": "ok"}
