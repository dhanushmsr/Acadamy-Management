from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.db import init_db
from app.routers import academies, attendance, audit, auth, batches, payments, students, team, users


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Beanie needs an async call to register document models before any
    # query works - this is that call, run once on startup.
    await init_db()
    yield


app = FastAPI(title="Actmac API (MongoDB)", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # tighten this to your real domains before production
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(academies.router)
app.include_router(users.router)
app.include_router(students.router)
app.include_router(batches.router)
app.include_router(team.router)
app.include_router(payments.router)
app.include_router(attendance.router)
app.include_router(audit.router)


@app.get("/health")
async def health():
    return {"status": "ok"}
