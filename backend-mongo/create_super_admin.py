"""
Run once, from inside the backend-mongo/ folder, to create the
platform's first login. There's no signup route for super_admin on
purpose (it's the platform owner - you shouldn't be able to create that
account over the public API), so this is the intended way to bootstrap
it.

This creates the SAME account as backend/create_super_admin.py - same
name, phone, email, and password - so either database ends up with an
identical first login.

Usage:
    python create_super_admin.py
"""
import asyncio

from beanie import init_beanie
from motor.motor_asyncio import AsyncIOMotorClient

from app.core.config import settings
from app.core.security import hash_password
from app.models import User, UserRole

SUPER_ADMIN_NAME = "Dhanush"
SUPER_ADMIN_PHONE = "+919566960500"
SUPER_ADMIN_EMAIL = "dhanushdsm6351364@gmail.com"
SUPER_ADMIN_PASSWORD = "xJBv7Op24oM3C3"  # change this after first login


async def main():
    client = AsyncIOMotorClient(settings.mongodb_url)
    db = client[settings.mongodb_db_name]
    await init_beanie(database=db, document_models=[User])

    existing = await User.find_one(User.email == SUPER_ADMIN_EMAIL)
    if existing:
        print(f"A user with email {SUPER_ADMIN_EMAIL} already exists - not creating a duplicate.")
        return

    admin = User(
        name=SUPER_ADMIN_NAME,
        email=SUPER_ADMIN_EMAIL,
        phone=SUPER_ADMIN_PHONE,
        hashed_password=hash_password(SUPER_ADMIN_PASSWORD),
        role=UserRole.super_admin,
    )
    await admin.insert()

    print("Super admin created.")
    print(f"  Email:    {SUPER_ADMIN_EMAIL}")
    print(f"  Phone:    {SUPER_ADMIN_PHONE}")
    print(f"  Password: {SUPER_ADMIN_PASSWORD}")
    print("Change the password after your first login.")


if __name__ == "__main__":
    asyncio.run(main())
