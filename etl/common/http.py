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
