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
    """Retourne (rows, meta) pour les N derniers fixtures via param last."""
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
