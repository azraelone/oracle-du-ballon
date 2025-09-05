import os
import sys
import time

DATABASE_URL = os.getenv("DATABASE_URL")
FD_API_KEY = os.getenv("FD_API_KEY")
API_FOOTBALL_KEY = os.getenv("API_FOOTBALL_KEY")

print("[ETL] Boot...")
print(f"[ETL] DATABASE_URL present: {bool(DATABASE_URL)}")
print(f"[ETL] FD_API_KEY present: {bool(FD_API_KEY)}")
print(f"[ETL] API_FOOTBALL_KEY present: {bool(API_FOOTBALL_KEY)}")

# Ici tu brancheras ta logique ETL réelle (ingest équipes, matchs, etc.)
time.sleep(1)
print("[ETL] OK (placeholder).")
sys.exit(0)
