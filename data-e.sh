set -euo pipefail

# === Réglages répertoire dépôt ===
REPO_DIR="${HOME}/oracle-du-ballon"
mkdir -p "$REPO_DIR"
cd "$REPO_DIR"

# === Arborescence ===
mkdir -p etl/common etl/jobs etl/scripts db docs

# === .env.example (ajout variables nécessaires si non présent) ===
if [ ! -f .env.example ]; then
  cat > .env.example <<'EOF'
# --- Base de données ---
DATABASE_URL=postgresql+psycopg2://oracle:oracle@db:5432/oracle_db

# --- API ---
API_FOOTBALL_KEY=changeme
FOOTBALL_DATA_KEY=changeme

# --- Paramètres Ligue 1 ---
L1_LEAGUE_ID=61
SEASON=2025
EOF
fi

# === Requirements ETL ===
cat > etl/requirements.txt <<'EOF'
requests>=2.32
urllib3>=2.2
python-dotenv>=1.0
SQLAlchemy>=2.0
psycopg2-binary>=2.9
EOF

# === Dockerfile pour le service ETL ===
cat > etl/Dockerfile <<'EOF'
FROM python:3.12-slim
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
COPY etl/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt
COPY etl /app/etl
COPY db /app/db
CMD ["python","-c","print('ETL container ready')"]
EOF

# === docker-compose.override.yml : ajoute le service etl (sans toucher ton compose existant) ===
cat > docker-compose.override.yml <<'EOF'
services:
  etl:
    build:
      context: .
      dockerfile: etl/Dockerfile
    env_file:
      - .env
    depends_on:
      - db
    volumes:
      - ./:/app:rw
    working_dir: /app
EOF

# === Modèles SQLAlchemy (tables) ===
cat > etl/models.py <<'EOF'
from sqlalchemy import Table, Column, BigInteger, Integer, String, DateTime, MetaData, ForeignKey, Text
from sqlalchemy.dialects.postgresql import insert
metadata = MetaData(schema=None)

teams = Table(
    "teams", metadata,
    Column("id", BigInteger, primary_key=True),
    Column("name", String(200), nullable=False),
    Column("short_name", String(50)),
    Column("crest_url", Text),
)

players = Table(
    "players", metadata,
    Column("id", BigInteger, primary_key=True),
    Column("team_id", BigInteger, ForeignKey("teams.id", ondelete="CASCADE"), index=True),
    Column("name", String(200), nullable=False),
    Column("position", String(50)),
)

matches = Table(
    "matches", metadata,
    Column("id", BigInteger, primary_key=True),
    Column("season", Integer, index=True),
    Column("round", String(50)),
    Column("date_utc", DateTime(timezone=True), index=True),
    Column("home_id", BigInteger, ForeignKey("teams.id", ondelete="SET NULL"), index=True),
    Column("away_id", BigInteger, ForeignKey("teams.id", ondelete="SET NULL"), index=True),
    Column("goals_home", Integer),
    Column("goals_away", Integer),
    Column("status", String(10), index=True),
)

events = Table(
    "events", metadata,
    Column("match_id", BigInteger, ForeignKey("matches.id", ondelete="CASCADE"), primary_key=True),
    Column("minute", Integer, primary_key=True),
    Column("type", String(50), primary_key=True),
    Column("player_id", BigInteger, nullable=True),
    Column("team_id", BigInteger, ForeignKey("teams.id", ondelete="SET NULL")),
)

def upsert(conn, table, rows, key_cols):
    """Idempotent UPSERT pour PostgreSQL via ON CONFLICT."""
    if not rows:
        return 0
    stmt = insert(table).values(rows)
    update_cols = {c.name: stmt.excluded[c.name] for c in table.columns if c.name not in key_cols}
    stmt = stmt.on_conflict_do_update(index_elements=[table.c[k] for k in key_cols], set_=update_cols)
    res = conn.execute(stmt)
    return res.rowcount or 0
EOF

# === Config & DB utilitaires ===
cat > etl/common/config.py <<'EOF'
import os
from dotenv import load_dotenv
load_dotenv()
API_FOOTBALL_KEY = os.getenv("API_FOOTBALL_KEY", "")
FOOTBALL_DATA_KEY = os.getenv("FOOTBALL_DATA_KEY", "")
DATABASE_URL = os.getenv("DATABASE_URL", "")
L1_LEAGUE_ID = int(os.getenv("L1_LEAGUE_ID", "61"))
SEASON = int(os.getenv("SEASON", "2025"))
EOF

cat > etl/common/db.py <<'EOF'
import sys
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine
from etl.common.config import DATABASE_URL

def get_engine() -> Engine:
    if not DATABASE_URL:
        print("[ERR] DATABASE_URL manquant dans .env", file=sys.stderr)
        sys.exit(4)
    return create_engine(DATABASE_URL, pool_pre_ping=True)
EOF

cat > etl/common/http.py <<'EOF'
import sys, time
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

def session_with_retries(total=5, backoff_factor=0.7, timeout=20):
    retries = Retry(
        total=total,
        backoff_factor=backoff_factor,
        status_forcelist=[429, 500, 502, 503, 504],
        allowed_methods=["HEAD","GET","OPTIONS"]
    )
    s = requests.Session()
    s.mount("https://", HTTPAdapter(max_retries=retries))
    s.mount("http://", HTTPAdapter(max_retries=retries))
    s.request_timeout = timeout
    return s

def get_json(s, url, headers=None, params=None):
    try:
        r = s.get(url, headers=headers, params=params, timeout=getattr(s, "request_timeout", 20))
        if r.status_code == 429:
            retry_after = int(r.headers.get("Retry-After", "3"))
            print(f"[WARN] 429 Rate limit, pause {retry_after}s…")
            time.sleep(retry_after)
            r = s.get(url, headers=headers, params=params, timeout=getattr(s, "request_timeout", 20))
        r.raise_for_status()
        return r.json()
    except requests.RequestException as e:
        print(f"[ERR] API call failed: {e}", file=sys.stderr)
        sys.exit(2)
EOF

# === Script création du schéma via SQLAlchemy (idempotent) ===
cat > etl/scripts/create_schema.py <<'EOF'
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
EOF

# === Job: import_teams (API-Football) ===
cat > etl/jobs/import_teams.py <<'EOF'
import sys
from etl.common.config import API_FOOTBALL_KEY, L1_LEAGUE_ID, SEASON
from etl.common.http import session_with_retries, get_json
from etl.common.db import get_engine
from etl.models import teams, upsert

API = "https://v3.football.api-sports.io"

def short_name_from(team):
    # Essaie code, sinon nom tronqué
    code = (team.get("code") or "").strip()
    if code:
        return code
    name = (team.get("name") or "").strip()
    return name[:15]

def main():
    if not API_FOOTBALL_KEY:
        print("[ERR] API_FOOTBALL_KEY manquant dans .env", file=sys.stderr)
        sys.exit(4)

    s = session_with_retries()
    headers = {"x-apisports-key": API_FOOTBALL_KEY}
    params = {"league": L1_LEAGUE_ID, "season": SEASON}
    data = get_json(s, f"{API}/teams", headers=headers, params=params)

    rows = []
    for item in data.get("response", []):
        t = item.get("team", {})
        rows.append({
            "id": t.get("id"),
            "name": t.get("name"),
            "short_name": short_name_from(t),
            "crest_url": t.get("logo"),
        })

    engine = get_engine()
    with engine.begin() as conn:
        n = upsert(conn, teams, rows, key_cols=["id"])
    print(f"[OK] import_teams: upsert {n} lignes.")
    sys.exit(0)

if __name__ == "__main__":
    main()
EOF

# === Job: import_fixtures (API-Football) ===
cat > etl/jobs/import_fixtures.py <<'EOF'
import sys, argparse, datetime as dt
from dateutil import tz
from etl.common.config import API_FOOTBALL_KEY, L1_LEAGUE_ID, SEASON
from etl.common.http import session_with_retries, get_json
from etl.common.db import get_engine
from etl.models import matches, upsert
from sqlalchemy import select
from sqlalchemy.sql import text as sqtext

API = "https://v3.football.api-sports.io"

def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--last", type=int, default=10, help="Importer les N derniers matchs (résultats/programmés)")
    return p.parse_args()

def main():
    if not API_FOOTBALL_KEY:
        print("[ERR] API_FOOTBALL_KEY manquant dans .env", file=sys.stderr)
        sys.exit(4)
    args = parse_args()
    s = session_with_retries()
    headers = {"x-apisports-key": API_FOOTBALL_KEY}
    params = {"league": L1_LEAGUE_ID, "season": SEASON, "last": max(1, args.last)}
    data = get_json(s, f"{API}/fixtures", headers=headers, params=params)

    rows = []
    for item in data.get("response", []):
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

    engine = get_engine()
    with engine.begin() as conn:
        n = upsert(conn, matches, rows, key_cols=["id"])
    print(f"[OK] import_fixtures: upsert {n} lignes (last={args.last}).")
    sys.exit(0)

if __name__ == "__main__":
    main()
EOF

# === Job: import_events (API-Football) ===
cat > etl/jobs/import_events.py <<'EOF'
import sys, argparse
from etl.common.config import API_FOOTBALL_KEY
from etl.common.http import session_with_retries, get_json
from etl.common.db import get_engine
from etl.models import events, matches, upsert
from sqlalchemy import select

API = "https://v3.football.api-sports.io"

def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--limit", type=int, default=10, help="Nombre de matchs récents (par id desc) pour événements")
    return p.parse_args()

def main():
    if not API_FOOTBALL_KEY:
        print("[ERR] API_FOOTBALL_KEY manquant dans .env", file=sys.stderr)
        sys.exit(4)
    args = parse_args()
    s = session_with_retries()
    headers = {"x-apisports-key": API_FOOTBALL_KEY}

    engine = get_engine()
    with engine.begin() as conn:
        match_ids = [r[0] for r in conn.execute(select(matches.c.id).order_by(matches.c.id.desc()).limit(args.limit)).fetchall()]

    total = 0
    rows_all = []
    for mid in match_ids:
        data = get_json(s, f"{API}/fixtures/events", headers=headers, params={"fixture": mid})
        for item in data.get("response", []):
            ev = {
                "match_id": mid,
                "minute": ((item.get("time") or {}).get("elapsed") or 0),
                "type": (item.get("type") or "Unknown"),
                "player_id": ((item.get("player") or {}).get("id")),
                "team_id": ((item.get("team") or {}).get("id")),
            }
            rows_all.append(ev)

    with engine.begin() as conn:
        # Contrainte PK (match_id, minute, type) => insertion unique par "signature"
        total = upsert(conn, events, rows_all, key_cols=["match_id","minute","type"])
    print(f"[OK] import_events: upsert {total} événements (sur {len(set([r['match_id'] for r in rows_all]))} matchs).")
    sys.exit(0)

if __name__ == "__main__":
    main()
EOF

# === Job: update_increments (rafraîchit dernières fixtures) ===
cat > etl/jobs/update_increments.py <<'EOF'
import sys
from etl.jobs.import_fixtures import main as import_fixtures_main
if __name__ == "__main__":
    # Rafraîchit les 30 derniers matchs : scores/report/status
    sys.argv = [sys.argv[0], "--last", "30"]
    import_fixtures_main()
EOF

# === Doc d’exploitation ===
cat > docs/02-etl.md <<'EOF'
# Phase 1 — ETL / Données (Ligue 1)

## Variables requises (.env)
- DATABASE_URL (ex: postgresql+psycopg2://oracle:oracle@db:5432/oracle_db)
- API_FOOTBALL_KEY
- L1_LEAGUE_ID=61
- SEASON=2025

## Construction / Lancement
```bash
docker compose build etl
docker compose run --rm etl python -m etl.scripts.create_schema
docker compose run --rm etl python -m etl.jobs.import_teams
docker compose run --rm etl python -m etl.jobs.import_fixtures --last 10
docker compose run --rm etl python -m etl.jobs.import_events --limit 10
