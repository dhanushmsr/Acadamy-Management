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

# For local/dev use only. Replace with Alembic migrations before production.
Base.metadata.create_all(bind=engine)

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
