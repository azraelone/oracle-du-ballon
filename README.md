# ⚽ Oracle du Ballon

Application complète pour la collecte, le suivi et la prédiction des résultats du championnat de France **Ligue 1**.

---

## 🚀 Stack technique

- **Backend** : Python (FastAPI)
- **Base de données** : PostgreSQL
- **Frontend** : React / Next.js
- **ETL** : Scripts Python (Football-Data.org / API-Sports)
- **Conteneurs** : Docker & Docker Compose

---

## 📊 Fonctionnalités prévues

- Collecte des données (équipes, joueurs, matchs, événements).
- Base de données relationnelle optimisée.
- API REST (FastAPI) :
  - `/matches/upcoming` → matchs à venir
  - `/matches/results` → résultats passés
  - `/teams/:id` → stats d’une équipe
  - `/predictions/:match_id` → prévisions
- Frontend interactif (React) : dashboard, fiches équipes/joueurs, page de prédictions.
- Module de prédiction (statistiques + machine learning).

---

## 🧑‍💻 Démarrage rapide

### 1) Cloner le repo
```bash
git clone https://github.com/azraelone/oracle-du-ballon.git
cd oracle-du-ballon
2) Configurer l’environnement
Créer un fichier .env basé sur .env.example :

bash
Copier le code
cp .env.example .env
Modifier avec vos vraies valeurs (clés API et DATABASE_URL).

3) Lancer les services
bash
Copier le code
docker compose up -d --build
4) Vérifier la base
bash
Copier le code
docker compose exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "\dt"

---

## 📂 Documentation

- **[ETL / Phase 1](docs/02-etl.md)** → création du schéma, jobs d’import, vérifications, automatisation.

---

## 📌 Notes

- En **plan gratuit API-Sports**, seules les saisons 2021–2023 sont accessibles.  
- Le projet utilise actuellement **Football-Data.org** pour les équipes et fixtures (SEASON=2023).  
- Pour les événements détaillés (buts, cartons…), API-Sports payant sera requis.  
- Phase 1.1 prévue : ajout d’une table `team_alias` pour combiner plusieurs sources sans conflits d’IDs.
