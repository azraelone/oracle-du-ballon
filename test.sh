set -euo pipefail
cd "$HOME/oracle-du-ballon"

############################
# 0) ENV : ajouter paramètres fallback
############################
# Ajout/maj des variables .env (non destructif)
grep -q '^ETL_SOURCE=' .env 2>/dev/null || echo 'ETL_SOURCE=auto' >> .env
grep -q '^FD_COMP='   .env 2>/dev/null || echo 'FD_COMP=FL1'     >> .env
# S’assurer que les clés sont présentes (mets tes vraies valeurs si besoin)
grep -q '^API_FOOTBALL_KEY=' .env || echo 'API_FOOTBALL_KEY=99ad862f120ccaf24a895b6160b308a9' >> .env
grep -q '^FOOTBALL_DATA_KEY=' .env || echo 'FOOTBALL_DATA_KEY=d9983332499a46c8b470c86217271c39' >> .env
# Si L1_LEAGUE_ID/SEASON absents, on met par défaut une saison compatible plan gratuit API-Sports
grep -q '^L1_LEAGUE_ID=' .env || echo 'L1_LEAGUE_ID=61' >> .env
grep -q '^SEASON=' .env || echo 'SEASON=2023' >> .env

############################
# 1) Dossiers / __init__.py
############################
mkdir -p etl/sources etl/common etl/jobs etl/scripts
: > etl/__init__.py
: > etl/common/__init__.py
: > etl/jobs/__init__.py
: > etl/scripts/__init__.py
: > etl/sources/__init__.py

############################
# 2) Config : lire ETL_SOURCE / FD_COMP
############################
# (met à jour le fichier si le bloc n’existe pas déjà)
if ! grep -q 'ETL_SOURCE' etl/common/config.py; then
  cat >> etl/common/config.py <<'PY'

# --- Fallback / sélection de source ---
# ETL_SOURCE peut valoir: "apisports", "footballdata" ou "auto" (par défaut)
ETL_SOURCE = os.getenv("ETL_SOURCE", "auto").lower()
FD_COMP = os.getenv("FD_COMP", "FL1")  # Ligue 1 = FL1 sur football-data.org
PY
fi

############################
# 3) Source: API-Sports (v3)
############################
cat > etl/sources/apisports.py <<'PY'
import sys
from etl.common.http import session_with_retries, get_json
from etl.common.config import API_FOOTBALL_KEY

API = "https://v3.football.api-sports.io"

def _check_key():
    if not API_FOOTBALL_KEY:
        print("[ERR] API_FOOTBALL_KEY manquante dans .env", file=sys.stderr)
        return False
    return True

def teams(league_id:int, season:int):
    """Retourne (rows, meta) ou ([], {'error': <raison>})"""
    if not _check_key():
        return [], {"error":"missing_key"}
    s = session_with_retries()
    headers = {"x-apisports-key": API_FOOTBALL_KEY}
    params = {"league": league_id, "season": season}
    data = get_json(s, f"{API}/teams", headers=headers, params=params)
    errs = data.get("errors") or {}
    resp = data.get("response") or []
    rows = []
    for item in resp:
        t = item.get("team", {})
        rows.append({
            "id": t.get("id"),
            "name": t.get("name"),
            "short_name": (t.get("code") or (t.get("name") or "")[:15]),
            "crest_url": t.get("logo"),
        })
    meta = {"errors": errs, "count": len(resp)}
    return rows, meta

def fixtures_last(league_id:int, season:int, last:int):
    """Retourne (rows, meta) en prenant les N derniers fixtures publiés par l'API (param last)."""
    if not _check_key():
        return [], {"error":"missing_key"}
    s = session_with_retries()
    headers = {"x-apisports-key": API_FOOTBALL_KEY}
    params = {"league": league_id, "season": season, "last": max(1, last)}
    data = get_json(s, f"{API}/fixtures", headers=headers, params=params)
    errs = data.get("errors") or {}
    resp = data.get("response") or []
    rows = []
    for item in resp:
        fx = item.get("fixture", {})
        lg = item.get("league", {})
        tm = item.get("teams", {})
        gl = item.get("goals", {})
        rows.append({
            "id": fx.get("id"),
            "season": lg.get("season"),
            "round": lg.get("round"),
            "date_utc": fx.get("date"),
            "home_id": tm.get("home", {}).get("id"),
            "away_id": tm.get("away", {}).get("id"),
            "goals_home": gl.get("home"),
            "goals_away": gl.get("away"),
            "status": (fx.get("status") or {}).get("short"),
        })
    meta = {"errors": errs, "count": len(resp)}
    return rows, meta
PY

############################
# 4) Source: Football-Data.org (v4)
############################
cat > etl/sources/footballdata.py <<'PY'
import sys, datetime as dt
from etl.common.http import session_with_retries, get_json
from etl.common.config import FOOTBALL_DATA_KEY, FD_COMP, SEASON

API = "https://api.football-data.org/v4"

def _check_key():
    if not FOOTBALL_DATA_KEY:
        print("[ERR] FOOTBALL_DATA_KEY manquante dans .env", file=sys.stderr)
        return False
    return True

def _status_map_fd_to_short(s: str) -> str:
    # FD status → codes courts proches d'API-Sports
    s = (s or "").upper()
    return {
        "SCHEDULED": "NS",
        "TIMED":     "NS",
        "IN_PLAY":   "1H",
        "PAUSED":    "HT",
        "FINISHED":  "FT",
        "POSTPONED": "PST",
        "SUSPENDED": "SUS",
        "CANCELED":  "CANC",
    }.get(s, s[:3] or "UNK")

def teams(season:int):
    """Retourne (rows, meta) pour une compétition FD_COMP et une season."""
    if not _check_key():
        return [], {"error":"missing_key"}
    s = session_with_retries()
    headers = {"X-Auth-Token": FOOTBALL_DATA_KEY}
    params = {"season": season}
    data = get_json(s, f"{API}/competitions/{FD_COMP}/teams", headers=headers, params=params)
    resp = data.get("teams") or []
    rows = []
    for t in resp:
        rows.append({
            "id": t.get("id"),
            "name": t.get("name"),
            "short_name": (t.get("tla") or (t.get("shortName") or t.get("name",""))[:15]),
            "crest_url": t.get("crest"),
        })
    meta = {"count": len(resp)}
    return rows, meta

def fixtures_season(season:int, last:int):
    """Retourne (rows, meta) sur toute la saison FD, puis tronque aux N plus récents par date."""
    if not _check_key():
        return [], {"error":"missing_key"}
    s = session_with_retries()
    headers = {"X-Auth-Token": FOOTBALL_DATA_KEY}
    params = {"season": season}
    data = get_json(s, f"{API}/competitions/{FD_COMP}/matches", headers=headers, params=params)
    resp = data.get("matches") or []
    # Tri par date croissante, puis on prend les N derniers
    resp_sorted = sorted(resp, key=lambda m: m.get("utcDate") or "")
    if last and last > 0:
        resp_sorted = resp_sorted[-last:]
    rows = []
    for m in resp_sorted:
        rows.append({
            "id": m.get("id"),
            "season": season,
            "round": (m.get("matchday") and f"MD-{m.get('matchday')}") or None,
            "date_utc": m.get("utcDate"),
            "home_id": ((m.get("homeTeam") or {}).get("id")),
            "away_id": ((m.get("awayTeam") or {}).get("id")),
            "goals_home": ((m.get("score") or {}).get("fullTime") or {}).get("home"),
            "goals_away": ((m.get("score") or {}).get("fullTime") or {}).get("away"),
            "status": _status_map_fd_to_short(m.get("status")),
        })
    meta = {"count": len(rows)}
    return rows, meta
PY

############################
# 5) Jobs : utiliser la sélection de source + fallback
############################

# --- import_teams.py ---
cat > etl/jobs/import_teams.py <<'PY'
import sys
from etl.common.config import ETL_SOURCE, L1_LEAGUE_ID, SEASON
from etl.common.db import get_engine
from etl.models import teams, upsert

from etl.sources import apisports as A
from etl.sources import footballdata as F

def _insert(rows):
    engine = get_engine()
    with engine.begin() as conn:
        return upsert(conn, teams, rows, key_cols=["id"])

def main():
    rows = []
    source_used = None

    if ETL_SOURCE in ("apisports", "auto"):
        rows_api, meta = A.teams(L1_LEAGUE_ID, SEASON)
        if rows_api and (meta.get("count", 0) > 0):
            rows = rows_api
            source_used = "apisports"
        else:
            # Fallback si auto
            errs = (meta.get("errors") if isinstance(meta, dict) else {}) or {}
            if ETL_SOURCE == "auto" and (errs or meta.get("count",0)==0):
                print("[INFO] Fallback → Football-Data.org (teams)")
            elif ETL_SOURCE == "apisports":
                # Pas de fallback autorisé
                print(f"[ERR] import_teams (apisports): aucune donnée (errors={errs})", file=sys.stderr)
                sys.exit(1)

    if not rows and ETL_SOURCE in ("footballdata", "auto"):
        rows_fd, meta = F.teams(SEASON)
        if rows_fd:
            rows = rows_fd
            source_used = "footballdata"

    if not rows:
        print("[ERR] import_teams: aucune source n'a fourni de données.", file=sys.stderr)
        sys.exit(1)

    n = _insert(rows)
    print(f"[OK] import_teams ({source_used}): upsert {n} lignes.")
    sys.exit(0)

if __name__ == "__main__":
    main()
PY

# --- import_fixtures.py ---
cat > etl/jobs/import_fixtures.py <<'PY'
import sys, argparse
from etl.common.config import ETL_SOURCE, L1_LEAGUE_ID, SEASON
from etl.common.db import get_engine
from etl.models import matches, upsert

from etl.sources import apisports as A
from etl.sources import footballdata as F

def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--last", type=int, default=10, help="Importer les N derniers matchs (résultats/programmés)")
    return p.parse_args()

def _insert(rows):
    engine = get_engine()
    with engine.begin() as conn:
        return upsert(conn, matches, rows, key_cols=["id"])

def main():
    args = parse_args()
    rows = []
    source_used = None

    if ETL_SOURCE in ("apisports", "auto"):
        r, meta = A.fixtures_last(L1_LEAGUE_ID, SEASON, args.last)
        if r and (meta.get("count",0) > 0):
            rows = r
            source_used = "apisports"
        else:
            errs = (meta.get("errors") if isinstance(meta, dict) else {}) or {}
            if ETL_SOURCE == "auto" and (errs or meta.get("count",0)==0):
                print("[INFO] Fallback → Football-Data.org (fixtures)")
            elif ETL_SOURCE == "apisports":
                print(f"[ERR] import_fixtures (apisports): aucune donnée (errors={errs})", file=sys.stderr)
                sys.exit(1)

    if not rows and ETL_SOURCE in ("footballdata", "auto"):
        r, meta = F.fixtures_season(SEASON, args.last)
        if r:
            rows = r
            source_used = "footballdata"

    if not rows:
        print("[ERR] import_fixtures: aucune source n'a fourni de données.", file=sys.stderr)
        sys.exit(1)

    n = _insert(rows)
    print(f"[OK] import_fixtures ({source_used}): upsert {n} lignes (last={args.last}).")
    sys.exit(0)

if __name__ == "__main__":
    main()
PY

# --- import_events.py : avertir si source = footballdata ---
cat > etl/jobs/import_events.py <<'PY'
import sys, argparse, os
from etl.common.config import ETL_SOURCE
from etl.common.db import get_engine
from etl.models import events, matches, upsert
from etl.sources import apisports as A
from sqlalchemy import select

def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--limit", type=int, default=10, help="Nombre de matchs récents (par id desc) pour événements")
    return p.parse_args()

def main():
    if ETL_SOURCE == "footballdata":
        print("[WARN] import_events: événements détaillés non disponibles via Football-Data.org. Aucune insertion.", file=sys.stderr)
        sys.exit(0)

    # Si auto, on tentera API-Sports uniquement pour les events
    s_limit = parse_args().limit
    engine = get_engine()
    with engine.begin() as conn:
        match_ids = [r[0] for r in conn.execute(select(matches.c.id).order_by(matches.c.id.desc()).limit(s_limit)).fetchall()]

    # Appels API-Sports pour chaque match
    total = 0
    rows_all = []
    for mid in match_ids:
        try:
            # On réutilise directement la session helper d'API-Sports
            from etl.common.http import session_with_retries, get_json
            from etl.common.config import API_FOOTBALL_KEY
            if not API_FOOTBALL_KEY:
                print("[WARN] API_FOOTBALL_KEY manquante: skip events", file=sys.stderr)
                break
            s = session_with_retries()
            headers = {"x-apisports-key": API_FOOTBALL_KEY}
            data = get_json(s, "https://v3.football.api-sports.io/fixtures/events", headers=headers, params={"fixture": mid})
            for item in data.get("response", []):
                ev = {
                    "match_id": mid,
                    "minute": ((item.get("time") or {}).get("elapsed") or 0),
                    "type": (item.get("type") or "Unknown"),
                    "player_id": ((item.get("player") or {}).get("id")),
                    "team_id": ((item.get("team") or {}).get("id")),
                }
                rows_all.append(ev)
        except Exception as e:
            print(f"[WARN] Events fixture={mid}: {e}", file=sys.stderr)

    if not rows_all:
        print("[INFO] import_events: aucun événement inséré (voir avertissements).")
        sys.exit(0)

    with engine.begin() as conn:
        total = upsert(conn, events, rows_all, key_cols=["match_id","minute","type"])
    print(f"[OK] import_events: upsert {total} événements (sur {len(set([r['match_id'] for r in rows_all]))} matchs).")
    sys.exit(0)

if __name__ == "__main__":
    main()
PY

############################
# 6) Doc : mise à jour /docs/02-etl.md
############################
cat > docs/02-etl.md <<'MD'
# Phase 1 — ETL / Données (Ligue 1) avec fallback API

## Variables requises (.env)
- DATABASE_URL (ex: postgresql+psycopg2://oracle:oracle@db:5432/oracle_db)
- API_FOOTBALL_KEY (API-Sports)
- FOOTBALL_DATA_KEY (Football-Data.org)
- L1_LEAGUE_ID=61
- SEASON=2023   # (API-Sports Gratuit: saisons autorisées 2021–2023)
- ETL_SOURCE=auto  # apisports | footballdata | auto (auto = tente API-Sports puis bascule FD)
- FD_COMP=FL1

## Lancer (idempotent)
```bash
docker compose build etl
docker compose run --rm -T etl python -m etl.scripts.create_schema
docker compose run --rm -T etl python -m etl.jobs.import_teams
docker compose run --rm -T etl python -m etl.jobs.import_fixtures --last 10
docker compose run --rm -T etl python -m etl.jobs.import_events --limit 10  # NOP si source=footballdata
