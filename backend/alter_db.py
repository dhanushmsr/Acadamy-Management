import os
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    print("No DATABASE_URL found")
    exit(1)

engine = create_engine(DATABASE_URL)

with engine.connect() as conn:
    # Add default_fee to students
    try:
        conn.execute(text("ALTER TABLE students ADD COLUMN default_fee INTEGER;"))
        print("Successfully added default_fee to students.")
    except Exception as e:
        print(f"Info (default_fee): {e}")

    # Expenses table will be created by Base.metadata.create_all(bind=engine) automatically!
    # But just in case, we can create it if not exists.
    
    conn.commit()
    print("Database upgrade script completed.")
