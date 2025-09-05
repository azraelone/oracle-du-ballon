# 📌 Suivi du projet Oracle du Ballon

## État d’avancement

### ✅ Phase 1 — ETL / Données
- [x] Schéma PostgreSQL (tables `teams`, `players`, `matches`, `events`)
- [x] Jobs d’import :
  - `import_teams` (Football-Data.org, fanions inclus)
  - `import_fixtures` (10 derniers matchs)
  - `import_events` (API-Sports uniquement, non utilisé en plan gratuit)
- [x] Exécution idempotente (upsert OK)
- [x] Conteneur ETL Docker fonctionnel
- [x] Documentation `docs/02-etl.md`
- [x] Tests d’acceptation validés : `teams >= 18`, `matches >= 10`
- [x] Repo GitHub mis à jour (`main`)

### 🔄 Phase 2 — Backend (API REST FastAPI)
- [ ] Conteneur backend dédié
- [ ] Connexion PostgreSQL (SQLAlchemy)
- [ ] Endpoints : `/matches/upcoming`, `/matches/results`, `/teams/:id`
- [ ] Swagger/OpenAPI auto-généré
- [ ] Doc `docs/03-backend.md`

### ⏳ Phase 3 — Module de prédiction
- [ ] Collecte données historiques
- [ ] Modèle Poisson / Elo
- [ ] API `/predictions/:match_id`
- [ ] Intégration dans DB

### ⏳ Phase 4 — Frontend (React/Next.js)
- [ ] Dashboard Ligue 1
- [ ] Classement dynamique
- [ ] Fiches équipes & joueurs
- [ ] Page prédictions

### ⏳ Phase 5 — Déploiement
- [ ] Docker Compose complet (db + backend + frontend)
- [ ] CI/CD (GitHub Actions)
- [ ] Hébergement VM Azure / VPS
- [ ] Monitoring basique

---

## Dernière mise à jour
- **Phase 1 terminée avec succès (Janvier 2025).**
- Actuellement : préparation **Phase 2 — Backend**.
