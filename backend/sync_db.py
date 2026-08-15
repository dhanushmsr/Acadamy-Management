from app.db import engine
from app.models import Base

print("Syncing DB schemas...")
Base.metadata.create_all(bind=engine)
print("Sync complete.")
