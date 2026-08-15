"""
Run once, from inside the backend/ folder, to create the platform's
first login. There's no signup route for super_admin on purpose (it's
the platform owner - you shouldn't be able to create that account over
the public API), so this is the intended way to bootstrap it.

This creates ONE specific hardcoded account:
  name:     Dhanush   (read as "Danus" from voice input - matches your
                        name everywhere else in this project, e.g. the
                        MongoDB Atlas project. Edit SUPER_ADMIN_NAME
                        below if that's wrong.)
  phone:    +919566960500
  email:    dhanushdsm6351364@gmail.com  (not given this round - reused
                        from earlier in this conversation since login
                        is by email, not phone. Edit SUPER_ADMIN_EMAIL
                        below if this isn't right.)
  password: generated once, printed below AND at the end of this script

Usage:
    python create_super_admin.py
"""
from app.core.security import hash_password
from app.db import Base, SessionLocal, engine
from app.models import User, UserRole

SUPER_ADMIN_NAME = "Dhanush"
SUPER_ADMIN_PHONE = "+919566960500"
SUPER_ADMIN_EMAIL = "dhanushdsm6351364@gmail.com"
SUPER_ADMIN_PASSWORD = "xJBv7Op24oM3C3"  # change this after first login


def main():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()

    existing = db.query(User).filter(User.email == SUPER_ADMIN_EMAIL).first()
    if existing:
        print(f"A user with email {SUPER_ADMIN_EMAIL} already exists - not creating a duplicate.")
        db.close()
        return

    admin = User(
        name=SUPER_ADMIN_NAME,
        email=SUPER_ADMIN_EMAIL,
        phone=SUPER_ADMIN_PHONE,
        hashed_password=hash_password(SUPER_ADMIN_PASSWORD),
        role=UserRole.super_admin,
    )
    db.add(admin)
    db.commit()
    db.close()

    print("Super admin created.")
    print(f"  Email:    {SUPER_ADMIN_EMAIL}")
    print(f"  Phone:    {SUPER_ADMIN_PHONE}")
    print(f"  Password: {SUPER_ADMIN_PASSWORD}")
    print("Change the password after your first login.")


if __name__ == "__main__":
    main()
