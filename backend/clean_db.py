import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.db import SessionLocal
from app.models import User, Academy, Student, Batch, Payment, Attendance, Expense, Tournament, TournamentRegistration, Broadcast, BroadcastRecipient, AuditLog, UserRole

def clean_database():
    db = SessionLocal()
    try:
        users = db.query(User).all()
        print(f"Total Users before cleanup: {len(users)}")
        for u in users:
            print(f" - User: {u.email}, Role: {u.role}, Academy ID: {u.academy_id}")

        academies = db.query(Academy).all()
        print(f"Total Academies before cleanup: {len(academies)}")
        for a in academies:
            print(f" - Academy: {a.name} (ID: {a.id})")

        # Identify users and academies to keep
        dsm_user = db.query(User).filter(User.email.ilike("dsm123@gmail.com")).first()
        keep_user_ids = set()
        keep_academy_ids = set()

        if dsm_user:
            keep_user_ids.add(dsm_user.id)
            if dsm_user.academy_id:
                keep_academy_ids.add(dsm_user.academy_id)
            print(f"\n[KEEP] Found dsm123@gmail.com (ID: {dsm_user.id}, Academy: {dsm_user.academy_id})")

        super_admins = db.query(User).filter(User.role == UserRole.super_admin).all()
        for sa in super_admins:
            keep_user_ids.add(sa.id)
            print(f"[KEEP] Found Super Admin (Email: {sa.email}, ID: {sa.id})")

        # Academies to delete
        academies_to_delete = db.query(Academy).filter(~Academy.id.in_(keep_academy_ids)).all() if keep_academy_ids else db.query(Academy).all()
        delete_academy_ids = [a.id for a in academies_to_delete]

        if delete_academy_ids:
            print(f"\nDeleting dependent records for {len(delete_academy_ids)} academies...")
            delete_students = db.query(Student).filter(Student.academy_id.in_(delete_academy_ids)).all()
            delete_student_ids = [s.id for s in delete_students]

            if delete_student_ids:
                db.query(Attendance).filter(Attendance.student_id.in_(delete_student_ids)).delete(synchronize_session=False)
                db.query(Payment).filter(Payment.student_id.in_(delete_student_ids)).delete(synchronize_session=False)
                db.query(TournamentRegistration).filter(TournamentRegistration.student_id.in_(delete_student_ids)).delete(synchronize_session=False)

            db.query(Tournament).filter(Tournament.academy_id.in_(delete_academy_ids)).delete(synchronize_session=False)
            db.query(Expense).filter(Expense.academy_id.in_(delete_academy_ids)).delete(synchronize_session=False)
            db.query(BroadcastRecipient).delete(synchronize_session=False)
            db.query(Broadcast).filter(Broadcast.academy_id.in_(delete_academy_ids)).delete(synchronize_session=False)
            db.query(Student).filter(Student.academy_id.in_(delete_academy_ids)).delete(synchronize_session=False)
            db.query(Batch).filter(Batch.academy_id.in_(delete_academy_ids)).delete(synchronize_session=False)
            db.query(AuditLog).delete(synchronize_session=False)

        # Delete users not in keep_user_ids
        users_to_delete = db.query(User).filter(~User.id.in_(keep_user_ids)).all() if keep_user_ids else []
        print(f"Deleting {len(users_to_delete)} users...")
        for u in users_to_delete:
            print(f" - Deleting User: {u.email} (Role: {u.role})")
            db.delete(u)

        # Delete academies not in keep_academy_ids
        for a in academies_to_delete:
            print(f" - Deleting Academy: {a.name} (ID: {a.id})")
            db.delete(a)

        db.commit()
        print("\nDATABASE CLEANUP COMPLETED SUCCESSFULLY!")

        remaining_users = db.query(User).all()
        print(f"\nRemaining Users ({len(remaining_users)}):")
        for u in remaining_users:
            print(f" - {u.email} (Role: {u.role})")

        remaining_academies = db.query(Academy).all()
        print(f"\nRemaining Academies ({len(remaining_academies)}):")
        for a in remaining_academies:
            print(f" - {a.name} (ID: {a.id})")

    except Exception as e:
        db.rollback()
        print(f"Error during cleanup: {e}")
        raise
    finally:
        db.close()

if __name__ == "__main__":
    clean_database()
