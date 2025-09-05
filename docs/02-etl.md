# Phase 1 — ETL / Données (Ligue 1)

## 📦 Schéma Postgres
Tables créées automatiquement :
- `teams(id, name, short_name, crest_url)`
- `players(id, team_id, name, position)`
- `matches(id, season, round, date_utc, home_id, away_id, goals_home, goals_away, status)`
- `events(match_id, minute, type, player_id, team_id)`

Idempotent : rejouer le script ne casse rien.

---

## 🔑 Variables `.env`
- `DATABASE_URL=postgresql+psycopg2://oracle:oracle@db:5432/oracle_db`
- `FOOTBALL_DATA_KEY=…` (clé Football-Data.org)
- `API_FOOTBALL_KEY=…` (clé API-Sports, utilisée seulement si tu actives ETL_SOURCE=apisports/auto)
- `ETL_SOURCE=footballdata` (**verrouillé pour cohérence IDs**)
- `FD_COMP=FL1`
- `SEASON=2023` (plan gratuit Football-Data autorise 2023)

---

## ⚙️ Jobs ETL

### 1) Création du schéma
```bash
docker compose run --rm -T etl python -m etl.scripts.create_schema

