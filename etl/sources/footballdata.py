import sys
from etl.common.http import session_with_retries, get_json
from etl.common.config import FOOTBALL_DATA_KEY, FD_COMP

API = "https://api.football-data.org/v4"

def _check_key():
    if not FOOTBALL_DATA_KEY:
        print("[ERR] FOOTBALL_DATA_KEY manquante dans .env", file=sys.stderr)
        return False
    return True

def _status_map_fd_to_short(s: str) -> str:
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
    if not _check_key():
        return [], {"error":"missing_key"}
    s = session_with_retries()
    headers = {"X-Auth-Token": FOOTBALL_DATA_KEY}
    params = {"season": season}
    data = get_json(s, f"{API}/competitions/{FD_COMP}/matches", headers=headers, params=params)
    resp = data.get("matches") or []
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
