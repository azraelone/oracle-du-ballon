import sys
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine
from etl.common.config import DATABASE_URL

def get_engine() -> Engine:
    if not DATABASE_URL:
        print("[ERR] DATABASE_URL manquant dans .env", file=sys.stderr)
        sys.exit(4)
    return create_engine(DATABASE_URL, pool_pre_ping=True)
