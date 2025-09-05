import sys, argparse
from etl.common.config import ETL_SOURCE, L1_LEAGUE_ID, SEASON
from etl.common.db import get_engine
from etl.models import matches, upsert
from etl.sources import apisports as A
from etl.sources import footballdata as F

def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--last", type=int, default=10, help="Importer les N derniers matchs")
    return p.parse_args()

def _insert(rows):
    eng = get_engine()
    with eng.begin() as conn:
        return upsert(conn, matches, rows, key_cols=["id"])

def main():
    args = parse_args()
    rows = []
    used = None

    if ETL_SOURCE in ("apisports", "auto"):
        r, meta = A.fixtures_last(L1_LEAGUE_ID, SEASON, args.last)
        if r and meta.get("count", 0) > 0:
            rows, used = r, "apisports"
        elif ETL_SOURCE == "apisports":
            errs = (meta.get("errors") if isinstance(meta, dict) else {}) or {}
            print(f"[ERR] import_fixtures (apisports): aucune donnée (errors={errs})", file=sys.stderr)
            sys.exit(1)

    if not rows and ETL_SOURCE in ("footballdata", "auto"):
        r, meta = F.fixtures_season(SEASON, args.last)
        if r:
            rows, used = r, "footballdata"

    if not rows:
        print("[ERR] import_fixtures: aucune source n'a fourni de données.", file=sys.stderr)
        sys.exit(1)

    n = _insert(rows)
    print(f"[OK] import_fixtures ({used}): upsert {n} lignes (last={args.last}).")
    sys.exit(0)

if __name__ == "__main__":
    main()
