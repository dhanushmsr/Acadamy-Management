from app.db import engine
from sqlalchemy import text

with engine.connect() as conn:
    try:
        res = conn.execute(text("SELECT * FROM notifications;")).fetchall()
        print(f"Notifications: {res}")
    except Exception as e:
        print(f"Error querying notifications: {e}")
