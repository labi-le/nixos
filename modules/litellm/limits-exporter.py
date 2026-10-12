import argparse
import json
import os
import sys
import tempfile
import time
import urllib.request
from datetime import datetime

POOL_ENV_PATH = os.environ.get("LITELLM_POOL_ENV_PATH", "/run/agenix/opencode-go-pool-env")
CODEX_AUTH_PATH = os.environ.get("LITELLM_CODEX_AUTH_PATH", "/var/lib/litellm-chatgpt/auth.json")
METRIC_PATH = os.environ.get(
    "LITELLM_LIMITS_METRIC_PATH",
    "/var/lib/prometheus-node-textfile-collector/litellm-provider-limits.prom",
)
STATE_PATH = os.environ.get(
    "LITELLM_LIMITS_STATE_PATH",
    "/var/lib/litellm-limits-exporter/state.json",
)
ZEN_USAGE_URL = os.environ.get("OPENCODE_USAGE_URL", "https://opencode.ai/zen/go/v1/usage")
CODEX_USAGE_URL = os.environ.get("CHATGPT_USAGE_URL", "https://chatgpt.com/backend-api/wham/usage")
KEY_ENV_PREFIX = "LITELLM_OPENCODE_GO_KEY_"
ZEN_WINDOWS = ("rolling", "weekly", "monthly")
CODEX_WINDOWS = ("primary", "secondary")
TIMEOUT_SECONDS = 15
EMPTY_RUNS_BEFORE_FAILURE = 3
ZEN_USER_AGENT = "jcode/0.89.3"
CODEX_USER_AGENT = "codex_cli_rs/0.1.0"


def pool_keys():
    keys = {}
    try:
        with open(POOL_ENV_PATH, encoding="utf-8") as handle:
            for line in handle:
                name, _, value = line.strip().partition("=")
                if name.startswith(KEY_ENV_PREFIX) and value:
                    keys[name[len(KEY_ENV_PREFIX) :]] = value
    except OSError:
        keys = {}
    if keys:
        return keys
    return {
        name[len(KEY_ENV_PREFIX) :]: value
        for name, value in os.environ.items()
        if name.startswith(KEY_ENV_PREFIX) and value
    }


def fetch_json(url, headers):
    last = None
    for _ in range(2):
        try:
            request = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
                return json.load(response)
        except Exception as failure:
            last = failure
            time.sleep(2)
    raise last


def epoch(value):
    if value is None or value == "":
        return 0
    if isinstance(value, (int, float)):
        return int(value)
    return int(datetime.fromisoformat(str(value).replace("Z", "+00:00")).timestamp())


def zen_account(key):
    body = fetch_json(
        ZEN_USAGE_URL,
        {
            "Authorization": f"Bearer {key}",
            "accept": "application/json",
            "user-agent": ZEN_USER_AGENT,
        },
    )
    usage = body.get("usage") or {}
    return {window: dict(usage.get(window) or {}) for window in ZEN_WINDOWS}


def codex_account():
    with open(CODEX_AUTH_PATH, encoding="utf-8") as handle:
        auth = json.load(handle)
    body = fetch_json(
        CODEX_USAGE_URL,
        {
            "Authorization": f"Bearer {auth.get('access_token', '')}",
            "chatgpt-account-id": str(auth.get("account_id", "")),
            "originator": CODEX_USER_AGENT.split("/")[0],
            "user-agent": CODEX_USER_AGENT,
            "accept": "application/json",
        },
    )
    return {
        "account": str(auth.get("account_id", ""))[:8],
        "expires_at": epoch(auth.get("expires_at")),
        "body": body,
    }


def escaped(value):
    return str(value).replace("\\", "\\\\").replace('"', '\\"')


def zen_lines(now, accounts, failed):
    lines = [
        "# HELP litellm_opencode_go_fetch_ok 1 when this pool account answered the usage API.",
        "# TYPE litellm_opencode_go_fetch_ok gauge",
    ]
    for index in sorted(accounts):
        lines.append(f'litellm_opencode_go_fetch_ok{{account="{index}"}} 1')
    for index in sorted(failed):
        lines.append(f'litellm_opencode_go_fetch_ok{{account="{index}"}} 0')
    lines += [
        "# HELP litellm_opencode_go_used_percent Share of the window this pool account has spent.",
        "# TYPE litellm_opencode_go_used_percent gauge",
    ]
    for index in sorted(accounts):
        for window, data in accounts[index].items():
            if "percent" in data:
                lines.append(
                    f'litellm_opencode_go_used_percent{{account="{index}",window="{window}"}} {data["percent"]}'
                )
    lines += [
        "# HELP litellm_opencode_go_window_status 1 when the provider reports this window as rate-limited.",
        "# TYPE litellm_opencode_go_window_status gauge",
    ]
    for index in sorted(accounts):
        for window, data in accounts[index].items():
            limited = 1 if data.get("status") == "rate-limited" else 0
            lines.append(
                f'litellm_opencode_go_window_status{{account="{index}",window="{window}"}} {limited}'
            )
    lines += [
        "# HELP litellm_opencode_go_reset_at When this pool account's window resets, unix seconds.",
        "# TYPE litellm_opencode_go_reset_at gauge",
    ]
    for index in sorted(accounts):
        for window, data in accounts[index].items():
            if data.get("resetsAt"):
                lines.append(
                    f'litellm_opencode_go_reset_at{{account="{index}",window="{window}"}} {epoch(data["resetsAt"])}'
                )
    return lines


def codex_lines(account):
    body = account["body"]
    rate_limit = body.get("rate_limit") or {}
    labels = f'account="{escaped(account["account"])}",plan="{escaped(body.get("plan_type", ""))}"'
    lines = [
        "# HELP litellm_codex_fetch_ok 1 when the ChatGPT account answered the usage API.",
        "# TYPE litellm_codex_fetch_ok gauge",
        f'litellm_codex_fetch_ok{{{labels}}} 1',
        "# HELP litellm_codex_limit_reached 1 when the plan reports the limit as reached.",
        "# TYPE litellm_codex_limit_reached gauge",
        f'litellm_codex_limit_reached{{{labels}}} {1 if rate_limit.get("limit_reached") else 0}',
        "# HELP litellm_codex_token_expires_at When the stored OAuth access token expires, unix seconds.",
        "# TYPE litellm_codex_token_expires_at gauge",
    ]
    if account["expires_at"]:
        lines.append(f'litellm_codex_token_expires_at{{{labels}}} {account["expires_at"]}')
    lines += [
        "# HELP litellm_codex_window_present 1 when the plan reports this rate-limit window.",
        "# TYPE litellm_codex_window_present gauge",
        "# HELP litellm_codex_used_percent Share of the window this ChatGPT account has spent.",
        "# TYPE litellm_codex_used_percent gauge",
        "# HELP litellm_codex_window_seconds Length of this rate-limit window.",
        "# TYPE litellm_codex_window_seconds gauge",
        "# HELP litellm_codex_reset_at When this rate-limit window resets, unix seconds.",
        "# TYPE litellm_codex_reset_at gauge",
    ]
    for window in CODEX_WINDOWS:
        data = rate_limit.get(f"{window}_window") or {}
        series = f'{labels},window="{window}"'
        lines.append(f"litellm_codex_window_present{{{series}}} {1 if data else 0}")
        if not data:
            continue
        lines.append(
            f'litellm_codex_used_percent{{{series}}} {data.get("used_percent", 0)}'
        )
        lines.append(
            f'litellm_codex_window_seconds{{{series}}} {data.get("limit_window_seconds", 0)}'
        )
        if data.get("reset_at"):
            lines.append(
                f'litellm_codex_reset_at{{{series}}} {epoch(data["reset_at"])}'
            )
    lines += [
        "# HELP litellm_codex_model_available 1 when this model is callable on the account's plan.",
        "# TYPE litellm_codex_model_available gauge",
    ]
    for model, data in sorted((body.get("model_usage") or {}).items()):
        available = 1 if (data or {}).get("available") else 0
        lines.append(
            f'litellm_codex_model_available{{{labels},model="{escaped(model)}"}} {available}'
        )
    return lines


def render(now, zen, codex, errors, failed):
    lines = [
        "# HELP litellm_limits_exporter_last_run_timestamp_seconds When the limits exporter last ran.",
        "# TYPE litellm_limits_exporter_last_run_timestamp_seconds gauge",
        f"litellm_limits_exporter_last_run_timestamp_seconds {now}",
        "# HELP litellm_limits_exporter_success 1 when every provider answered.",
        "# TYPE litellm_limits_exporter_success gauge",
        f"litellm_limits_exporter_success {1 if not errors else 0}",
        "# HELP litellm_limits_source_up 1 when this upstream answered the usage API this run.",
        "# TYPE litellm_limits_source_up gauge",
        f'litellm_limits_source_up{{source="opencode-go"}} {1 if zen else 0}',
        f'litellm_limits_source_up{{source="codex"}} {1 if codex is not None else 0}',
    ]
    lines += zen_lines(now, zen, failed)
    if codex is not None:
        lines += codex_lines(codex)
    lines.append("")
    return "\n".join(lines)


def write_metric(text):
    directory = os.path.dirname(METRIC_PATH)
    os.makedirs(directory, exist_ok=True)
    handle, tmp = tempfile.mkstemp(prefix=".litellm-provider-limits.", dir=directory)
    with os.fdopen(handle, "w", encoding="utf-8") as out:
        os.fchmod(out.fileno(), 0o644)
        out.write(text)
    os.replace(tmp, METRIC_PATH)


def read_state():
    try:
        with open(STATE_PATH, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return {}


def write_state(state):
    os.makedirs(os.path.dirname(STATE_PATH), exist_ok=True)
    with open(STATE_PATH, "w", encoding="utf-8") as handle:
        json.dump(state, handle, indent=2)
        handle.write("\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--stdout", action="store_true", help="print the exposition instead of writing it")
    args = parser.parse_args()

    now = int(time.time())
    errors = []
    zen = {}
    failed = set()
    keys = pool_keys()
    if not keys:
        errors.append("opencode-go pool: no LITELLM_OPENCODE_GO_KEY_* keys found")
    for index, key in sorted(keys.items()):
        try:
            zen[index] = zen_account(key)
        except Exception as failure:
            failed.add(index)
            errors.append(f"opencode-go account {index}: {type(failure).__name__}: {failure}")
    codex = None
    try:
        codex = codex_account()
    except Exception as failure:
        errors.append(f"codex: {type(failure).__name__}: {failure}")

    empty = bool(errors) and not zen and codex is None
    streak = 0
    if not args.stdout:
        previous = read_state().get("empty_runs")
        streak = (previous if isinstance(previous, int) else 0) + 1 if empty else 0

    text = render(now, zen, codex, errors, failed)
    published = True
    if args.stdout:
        print(text, end="")
    else:
        try:
            write_metric(text)
        except OSError as failure:
            published = False
            print(f"could not publish the provider limits: {failure}", file=sys.stderr)
            errors.append(f"metric file: {type(failure).__name__}: {failure}")
        try:
            write_state({"empty_runs": streak})
        except OSError as failure:
            published = False
            print(f"could not record the run: {failure}", file=sys.stderr)
    for line in errors:
        print(line, file=sys.stderr)
    if not published:
        return 1
    if not empty:
        return 0
    if streak < EMPTY_RUNS_BEFORE_FAILURE:
        print(
            f"nothing answered: run {streak} of {EMPTY_RUNS_BEFORE_FAILURE} before the unit fails",
            file=sys.stderr,
        )
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
