import sys
from etl.jobs.import_fixtures import main as import_fixtures_main
if __name__ == "__main__":
    # Rafraîchit les 30 derniers matchs : scores/report/status
    sys.argv = [sys.argv[0], "--last", "30"]
    import_fixtures_main()
