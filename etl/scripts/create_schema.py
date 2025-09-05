import sys
from etl.common.db import get_engine
from etl.models import metadata
def main():
    try:
        engine = get_engine()
        with engine.begin() as conn:
            metadata.create_all(conn)
        print("[OK] Schéma créé/mis à jour (idempotent).")
    except Exception as e:
        print(f"[ERR] Schéma: {e}", file=sys.stderr)
        sys.exit(3)
if __name__ == "__main__":
    main()
