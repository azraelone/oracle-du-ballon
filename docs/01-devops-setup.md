# Oracle-du-Ballon — Setup DevOps

Ports: DB 5432, Backend 8000, Frontend 5173

Start:
  cp .env.example .env
  docker compose up -d --build

Healthchecks:
  - db → pg_isready
  - backend → GET /health
