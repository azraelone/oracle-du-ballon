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
