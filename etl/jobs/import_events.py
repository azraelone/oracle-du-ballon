import sys, argparse
from etl.common.config import ETL_SOURCE
from etl.common.db import get_engine
from etl.models import events, matches, upsert
from sqlalchemy import select
from etl.common.http import session_with_retries, get_json
from etl.common.config import API_FOOTBALL_KEY

def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--limit", type=int, default=10, help="Nombre de matchs récents à parcourir")
    return p.parse_args()

def main():
    if ETL_SOURCE == "footballdata":
        print("[WARN] import_events: non disponible via Football-Data.org. Aucune insertion.", file=sys.stderr)
        sys.exit(0)
    if not API_FOOTBALL_KEY:
        print("[WARN] API_FOOTBALL_KEY manquante: skip events", file=sys.stderr)
        sys.exit(0)

    args = parse_args()
    eng = get_engine()
    with eng.begin() as conn:
        ids = [r[0] for r in conn.execute(select(matches.c.id).order_by(matches.c.date_utc.desc()).limit(args.limit)).fetchall()]

    s = session_with_retries()
    headers = {"x-apisports-key": API_FOOTBALL_KEY}
    rows = []
    for mid in ids:
        try:
            data = get_json(s, "https://v3.football.api-sports.io/fixtures/events",
                            headers=headers, params={"fixture": mid})
            for it in data.get("response", []):
                rows.append({
                    "match_id": mid,
                    "minute": ((it.get("time") or {}).get("elapsed") or 0),
                    "type": (it.get("type") or "Unknown"),
                    "player_id": ((it.get("player") or {}).get("id")),
                    "team_id": ((it.get("team") or {}).get("id")),
                })
        except Exception as e:
            print(f"[WARN] Events fixture={mid}: {e}", file=sys.stderr)

    if not rows:
        print("[INFO] import_events: aucun événement inséré (voir avertissements).")
        sys.exit(0)

    with eng.begin() as conn:
        total = upsert(conn, events, rows, key_cols=["match_id","minute","type"])
    print(f"[OK] import_events: upsert {total} événements (sur {len(set([r['match_id'] for r in rows]))} matchs).")
    sys.exit(0)

if __name__ == "__main__":
    main()
