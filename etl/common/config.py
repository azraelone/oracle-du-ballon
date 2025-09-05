import os
from dotenv import load_dotenv
load_dotenv()
API_FOOTBALL_KEY = os.getenv("API_FOOTBALL_KEY", "")
FOOTBALL_DATA_KEY = os.getenv("FOOTBALL_DATA_KEY", "")
DATABASE_URL = os.getenv("DATABASE_URL", "")
L1_LEAGUE_ID = int(os.getenv("L1_LEAGUE_ID", "61"))
SEASON = int(os.getenv("SEASON", "2025"))

# --- Fallback / sélection de source ---
# ETL_SOURCE peut valoir: "apisports", "footballdata" ou "auto" (par défaut)
ETL_SOURCE = os.getenv("ETL_SOURCE", "auto").lower()
FD_COMP = os.getenv("FD_COMP", "FL1")  # Ligue 1 = FL1 sur football-data.org

# --- Fallback / sélection de source ---
ETL_SOURCE = os.getenv("ETL_SOURCE", "auto").lower()
FD_COMP = os.getenv("FD_COMP", "FL1")  # Ligue 1 = FL1 sur football-data.org

# --- Fallback / sélection de source ---
ETL_SOURCE = os.getenv("ETL_SOURCE", "auto").lower()
FD_COMP = os.getenv("FD_COMP", "FL1")  # Ligue 1 = FL1 sur football-data.org
