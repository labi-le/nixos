import base64
import json
import os
import sys
import tempfile
import time
import urllib.error
import urllib.parse
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
DEVICE_CODE_URL = os.environ.get(
    "CHATGPT_DEVICE_CODE_URL",
    "https://auth.openai.com/api/accounts/deviceauth/usercode",
)
DEVICE_TOKEN_URL = os.environ.get(
    "CHATGPT_DEVICE_TOKEN_URL",
    "https://auth.openai.com/api/accounts/deviceauth/token",
)
DEVICE_VERIFY_URL = os.environ.get("CHATGPT_DEVICE_VERIFY_URL", "https://auth.openai.com/codex/device")
DEVICE_REDIRECT_URI = os.environ.get(
    "CHATGPT_DEVICE_REDIRECT_URI",
    "https://auth.openai.com/deviceauth/callback",
)
DEVICE_POLL_SECONDS = 5
DEVICE_TIMEOUT_SECONDS = int(os.environ.get("CHATGPT_DEVICE_TIMEOUT_SECONDS", "900"))
REFRESH_AHEAD_SECONDS = int(os.environ.get("CHATGPT_REFRESH_AHEAD_SECONDS", "3600"))


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


def post_json(url, payload, form=False):
    if form:
        body = urllib.parse.urlencode(payload).encode()
        content_type = "application/x-www-form-urlencoded"
    else:
        body = json.dumps(payload).encode()
        content_type = "application/json"
    request = urllib.request.Request(
        url,
        data=body,
        headers={"content-type": content_type, "user-agent": USER_AGENT},
    )
    with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
        return json.load(response)


def request_device_code():
    data = post_json(DEVICE_CODE_URL, {"client_id": CLIENT_ID})
    device_auth_id = data.get("device_auth_id")
    user_code = data.get("user_code") or data.get("usercode")
    if not device_auth_id or not user_code:
        raise SystemExit(f"device code response missing fields: {data}")
    return device_auth_id, user_code


def poll_device_token(device_auth_id, user_code):
    deadline = time.time() + DEVICE_TIMEOUT_SECONDS
    while time.time() < deadline:
        try:
            data = post_json(
                DEVICE_TOKEN_URL,
                {"device_auth_id": device_auth_id, "user_code": user_code},
            )
        except urllib.error.HTTPError as failure:
            if failure.code not in (403, 404):
                raise
            data = {}
        if data.get("authorization_code"):
            return data
        time.sleep(DEVICE_POLL_SECONDS)
    raise SystemExit("device authorization timed out")


def exchange_authorization_code(code_data):
    tokens = post_json(
        TOKEN_URL,
        {
            "grant_type": "authorization_code",
            "code": code_data["authorization_code"],
            "redirect_uri": DEVICE_REDIRECT_URI,
            "client_id": CLIENT_ID,
            "code_verifier": code_data["code_verifier"],
        },
        form=True,
    )
    if not tokens.get("access_token") or not tokens.get("refresh_token"):
        raise SystemExit(f"token exchange response missing fields: {tokens}")
    return tokens


def device_login():
    device_auth_id, user_code = request_device_code()
    print(
        "ChatGPT device login:\n"
        f"1) Visit {DEVICE_VERIFY_URL}\n"
        f"2) Enter code: {user_code}\n"
        f"The code expires in {DEVICE_TIMEOUT_SECONDS // 60} minutes.",
        flush=True,
    )
    code_data = poll_device_token(device_auth_id, user_code)
    record = refreshed_record({}, exchange_authorization_code(code_data))
    write_auth(record)
    account = str(record.get("account_id", ""))[:8]
    write_metrics(metric_lines(account, 1, int(time.time())))
    print(f"chatgpt token: login complete, token expires {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime(record['expires_at']))}")


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


def refresh_and_publish(auth, account):
    if not unchanged_since(auth):
        print("chatgpt token: auth.json changed during the check; leaving it", file=sys.stderr)
        return 0

    try:
        tokens = refresh_tokens(auth.get("refresh_token", ""))
    except urllib.error.HTTPError as failure:
        body = failure.read().decode("utf-8", "replace")[:300]
        print(
            f"chatgpt token: refresh rejected with {failure.code}: {body}\n"
            "chatgpt token: run `systemctl start litellm-chatgpt-login` to sign in again",
            file=sys.stderr,
        )
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
        print("chatgpt token: auth.json changed during the refresh; discarding ours", file=sys.stderr)
        return 0
    write_auth(record)
    account = str(record.get("account_id", ""))[:8]

    status, failure = probe(record)
    if status == 200:
        print(f"chatgpt token: refreshed, token expires {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime(record['expires_at']))}")
        write_metrics(metric_lines(account, 1, int(time.time())))
        return 0
    if status in (401, 403):
        print(
            f"chatgpt token: refreshed token also rejected with {status}; "
            "run `systemctl start litellm-chatgpt-login` to sign in again",
            file=sys.stderr,
        )
        write_metrics(metric_lines(account, 0, int(time.time())))
        return 1
    print(f"chatgpt token: refreshed, probe answered {status or failure}", file=sys.stderr)
    return 0


def main():
    if "--login" in sys.argv[1:]:
        device_login()
        return 0

    try:
        auth = read_auth()
    except FileNotFoundError:
        print(
            f"chatgpt token: {AUTH_PATH} does not exist; "
            "run `systemctl start litellm-chatgpt-login` to sign in",
            file=sys.stderr,
        )
        return 1
    except (OSError, ValueError) as failure:
        print(f"chatgpt token: cannot read {AUTH_PATH} right now: {failure}", file=sys.stderr)
        return 0

    account = str(auth.get("account_id", ""))[:8]
    expires_at = auth.get("expires_at")
    if isinstance(expires_at, (int, float)) and expires_at - time.time() <= REFRESH_AHEAD_SECONDS:
        return refresh_and_publish(auth, account)

    status, failure = probe(auth)
    if status == 200:
        write_metrics(metric_lines(account, 1, int(time.time())))
        return 0
    if status != 401:
        print(f"chatgpt token: usage probe answered {status or failure}", file=sys.stderr)
        return 0

    return refresh_and_publish(auth, account)


if __name__ == "__main__":
    sys.exit(main())
