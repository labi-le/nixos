import base64
import json
import os
import sys
import tempfile
import time
import urllib.error
import urllib.request

AUTH_PATH = os.environ.get("LITELLM_CHATGPT_AUTH_PATH", "/var/lib/litellm-chatgpt/auth.json")
METRIC_PATH = os.environ.get(
    "LITELLM_CHATGPT_TOKEN_METRIC_PATH",
    "/var/lib/prometheus-node-textfile-collector/litellm-chatgpt-token.prom",
)
USAGE_URL = os.environ.get("CHATGPT_USAGE_URL", "https://chatgpt.com/backend-api/wham/usage")
TOKEN_URL = os.environ.get("CHATGPT_OAUTH_TOKEN_URL", "https://auth.openai.com/oauth/token")
CLIENT_ID = os.environ.get("CHATGPT_CLIENT_ID", "app_EMoamEEZ73f0CkXaXp7hrann")
USER_AGENT = os.environ.get("CHATGPT_USER_AGENT", "codex_cli_rs/0.1.0")
SCOPE = "openid profile email"
TIMEOUT_SECONDS = 20
AUTH_CLAIM = "https://api.openai.com/auth"


def read_auth():
    with open(AUTH_PATH, encoding="utf-8") as handle:
        return json.load(handle)


def jwt_claims(token):
    parts = str(token or "").split(".")
    if len(parts) < 2:
        return {}
    payload = parts[1] + "=" * (-len(parts[1]) % 4)
    try:
        return json.loads(base64.urlsafe_b64decode(payload))
    except Exception:
        return {}


def probe(auth):
    request = urllib.request.Request(
        USAGE_URL,
        headers={
            "Authorization": f"Bearer {auth.get('access_token', '')}",
            "chatgpt-account-id": str(auth.get("account_id", "")),
            "originator": USER_AGENT.split("/")[0],
            "user-agent": USER_AGENT,
            "accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            return response.status, None
    except urllib.error.HTTPError as failure:
        return failure.code, None
    except Exception as failure:
        return None, failure


def refresh_tokens(refresh_token):
    request = urllib.request.Request(
        TOKEN_URL,
        data=json.dumps(
            {
                "client_id": CLIENT_ID,
                "grant_type": "refresh_token",
                "refresh_token": refresh_token,
                "scope": SCOPE,
            }
        ).encode(),
        headers={"content-type": "application/json", "user-agent": USER_AGENT},
    )
    with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
        return json.load(response)


def refreshed_record(auth, tokens):
    access_token = tokens.get("access_token")
    claims = jwt_claims(access_token)
    account_id = (claims.get(AUTH_CLAIM) or {}).get("chatgpt_account_id")
    return {
        **auth,
        "access_token": access_token,
        "refresh_token": tokens.get("refresh_token") or auth.get("refresh_token"),
        "id_token": tokens.get("id_token") or auth.get("id_token"),
        "expires_at": int(claims.get("exp", 0)) or auth.get("expires_at"),
        "account_id": account_id or auth.get("account_id"),
    }


def unchanged_since(auth):
    try:
        return read_auth().get("access_token") == auth.get("access_token")
    except (OSError, ValueError):
        return False


def write_auth(auth):
    handle, tmp = tempfile.mkstemp(prefix=".auth.", dir=os.path.dirname(AUTH_PATH))
    with os.fdopen(handle, "w", encoding="utf-8") as out:
        os.fchmod(out.fileno(), 0o644)
        json.dump(auth, out)
    os.replace(tmp, AUTH_PATH)


def write_metrics(lines):
    directory = os.path.dirname(METRIC_PATH)
    os.makedirs(directory, exist_ok=True)
    handle, tmp = tempfile.mkstemp(prefix=".litellm-chatgpt-token.", dir=directory)
    with os.fdopen(handle, "w", encoding="utf-8") as out:
        os.fchmod(out.fileno(), 0o644)
        out.write("\n".join(lines) + "\n")
    os.replace(tmp, METRIC_PATH)


def metric_lines(account, valid, verdict_at):
    lines = [
        "# HELP litellm_codex_token_valid 1 when the stored ChatGPT token answered the usage API.",
        "# TYPE litellm_codex_token_valid gauge",
        f'litellm_codex_token_valid{{account="{account}"}} {valid}',
        "# HELP litellm_codex_token_check_timestamp_seconds When the check last reached a verdict.",
        "# TYPE litellm_codex_token_check_timestamp_seconds gauge",
        f'litellm_codex_token_check_timestamp_seconds{{account="{account}"}} {verdict_at}',
    ]
    return lines


def main():
    try:
        auth = read_auth()
    except FileNotFoundError:
        print(f"chatgpt token: {AUTH_PATH} does not exist; a device login is needed", file=sys.stderr)
        return 1
    except (OSError, ValueError) as failure:
        print(f"chatgpt token: cannot read {AUTH_PATH} right now: {failure}", file=sys.stderr)
        return 0

    account = str(auth.get("account_id", ""))[:8]
    status, failure = probe(auth)
    if status == 200:
        write_metrics(metric_lines(account, 1, int(time.time())))
        return 0
    if status != 401:
        print(f"chatgpt token: usage probe answered {status or failure}", file=sys.stderr)
        return 0

    if not unchanged_since(auth):
        print("chatgpt token: litellm rewrote auth.json during the check; leaving it", file=sys.stderr)
        return 0

    try:
        tokens = refresh_tokens(auth.get("refresh_token", ""))
    except urllib.error.HTTPError as failure:
        body = failure.read().decode("utf-8", "replace")[:300]
        print(f"chatgpt token: refresh rejected with {failure.code}: {body}", file=sys.stderr)
        write_metrics(metric_lines(account, 0, int(time.time())))
        return 1
    except Exception as failure:
        print(f"chatgpt token: refresh failed: {failure}", file=sys.stderr)
        return 0

    if not tokens.get("access_token"):
        print("chatgpt token: refresh returned no access token", file=sys.stderr)
        write_metrics(metric_lines(account, 0, int(time.time())))
        return 1

    record = refreshed_record(auth, tokens)
    if not unchanged_since(auth):
        print("chatgpt token: litellm rewrote auth.json during the refresh; discarding ours", file=sys.stderr)
        return 0
    write_auth(record)
    account = str(record.get("account_id", ""))[:8]

    status, failure = probe(record)
    if status == 200:
        print(f"chatgpt token: refreshed, token expires {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime(record['expires_at']))}")
        write_metrics(metric_lines(account, 1, int(time.time())))
        return 0
    if status in (401, 403):
        print(f"chatgpt token: refreshed token also rejected with {status}; device login needed", file=sys.stderr)
        write_metrics(metric_lines(account, 0, int(time.time())))
        return 1
    print(f"chatgpt token: refreshed, probe answered {status or failure}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
