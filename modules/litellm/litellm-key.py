import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone

URL = os.environ.get("LITELLM_URL", "https://llm.labile.cc")
KEY_FILES = (
    os.environ.get("LITELLM_KEY_FILE", ""),
    "/run/agenix/opencode-litellm-master-key",
    "/run/agenix/litellm-env",
)
MODELS = [name for name in os.environ.get("LITELLM_MODELS", "opencode-go-pool").split(",") if name]
USAGE = """usage: litellm-key [keys | logs [-f] [N] | totals [DAYS]]
                     | create ALIAS [DAYS]
                     | extend TARGET [DURATION]
                     | revoke TARGET

  keys                     per-key alias, expiry, spend, models (default)
  logs [-f] [N]            last N request log rows, default 20; -f keeps
                           printing new ones
  totals [DAYS]            spend, tokens and requests per alias over the last
                           DAYS days, default 7; reads the full request log,
                           so a very busy proxy makes this slow
  create ALIAS [DAYS]      new key for ALIAS, default 365 days, models from
                           LITELLM_MODELS (default opencode-go-pool); the key
                           is printed once and cannot be read back
  extend TARGET [DURATION] move the expiry to now + DURATION, default 365d
  revoke TARGET            delete the key; this cannot be undone

TARGET is an alias or a full sk-... value; DURATION is a litellm duration such
as 30d or 12h. env: LITELLM_URL, LITELLM_KEY_FILE, LITELLM_MODELS"""


def master_key():
    for path in KEY_FILES:
        if not path or not os.access(path, os.R_OK):
            continue
        with open(path, encoding="utf-8") as handle:
            for line in handle:
                if line.startswith("LITELLM_MASTER_KEY="):
                    return line.split("=", 1)[1].strip()
    sys.exit("litellm-key: no readable LITELLM_MASTER_KEY; set LITELLM_KEY_FILE")


def call(path, payload=None):
    body = None if payload is None else json.dumps(payload).encode()
    headers = {"Authorization": f"Bearer {master_key()}"}
    if body is not None:
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(f"{URL}{path}", data=body, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", "replace")
        sys.exit(f"litellm-key: {path} -> HTTP {error.code}: {detail[:300]}")
    except OSError as error:
        sys.exit(f"litellm-key: {URL}{path} unreachable: {error}")


def keys_and_names():
    keys = call("/key/list?return_full_object=true")["keys"]
    names = {key["token"]: (key.get("key_alias") or "-") for key in keys}
    names["litellm_proxy_master_key"] = "master"
    return keys, names


def target_token(target):
    if target.startswith("sk-"):
        return hashlib.sha256(target.encode()).hexdigest()
    keys, _ = keys_and_names()
    matches = [key["token"] for key in keys if key.get("key_alias") == target]
    if not matches:
        sys.exit(f"litellm-key: no key with alias {target}")
    if len(matches) > 1:
        sys.exit(f"litellm-key: {len(matches)} keys share the alias {target}; pass a full sk-... value")
    return matches[0]


def remaining(value):
    if not value:
        return "never"
    try:
        moment = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return value
    left = (moment - datetime.now(timezone.utc)).total_seconds()
    if left <= 0:
        return "expired"
    return f"{int(left // 86400)}d"


def money(value):
    value = value or 0.0
    if value == 0:
        return "0"
    if abs(value) >= 0.0001:
        return f"{value:.4f}"
    return f"{value:.2e}"


def render(rows):
    widths = [max(len(str(row[column])) for row in rows) for column in range(len(rows[0]))]
    for index, row in enumerate(rows):
        print("  ".join(str(cell).ljust(widths[column]) for column, cell in enumerate(row)).rstrip())
        if index == 0:
            print("  ".join("-" * width for width in widths))


def alias_of(row, names):
    raw = row.get("api_key") or ""
    if not raw:
        return "-"
    return names.get(raw, "other")


def cmd_keys():
    keys, _ = keys_and_names()
    rows = [("alias", "expires", "spend", "total", "models", "blocked")]
    for key in sorted(keys, key=lambda item: item.get("key_alias") or ""):
        rows.append(
            (
                key.get("key_alias") or "-",
                remaining(key.get("expires")),
                money(key.get("spend")),
                money(key.get("total_spend")),
                ",".join(key.get("models") or []) or "all",
                "yes" if key.get("blocked") else "no",
            )
        )
    render(rows)


LOG_HEADER = ("time", "alias", "model", "call", "spend", "tokens", "ms", "status")
FOLLOW_SECONDS = float(os.environ.get("LITELLM_FOLLOW_SECONDS", "5"))


def sorted_logs():
    logs = call("/spend/logs")
    logs.sort(key=lambda row: row.get("startTime") or "")
    return logs


def log_row(row, names):
    return (
        (row.get("startTime") or "")[:19].replace("T", " "),
        alias_of(row, names),
        row.get("model") or row.get("model_group") or "-",
        (row.get("call_type") or "-").lstrip("/"),
        money(row.get("spend")),
        row.get("total_tokens") or 0,
        int(row.get("request_duration_ms") or 0),
        row.get("status") or "-",
    )


def cmd_logs(count, follow=False):
    _, names = keys_and_names()
    logs = sorted_logs()
    render([LOG_HEADER] + [log_row(row, names) for row in logs[-count:]])
    if not follow:
        return
    seen = {row.get("request_id") for row in logs}
    while True:
        time.sleep(FOLLOW_SECONDS)
        try:
            fresh = sorted_logs()
        except SystemExit:
            continue
        new = [row for row in fresh if row.get("request_id") not in seen]
        seen.update(row.get("request_id") for row in new)
        if new:
            render([LOG_HEADER] + [log_row(row, names) for row in new])


def cmd_totals(days):
    _, names = keys_and_names()
    cutoff = (datetime.now(timezone.utc) - timedelta(days=days)).strftime("%Y-%m-%dT%H:%M:%S")
    totals = {}
    for row in call("/spend/logs"):
        if (row.get("startTime") or "") < cutoff:
            continue
        entry = totals.setdefault(alias_of(row, names), [0.0, 0, 0])
        entry[0] += row.get("spend") or 0.0
        entry[1] += row.get("total_tokens") or 0
        entry[2] += 1
    print(f"window: last {days}d, since {cutoff[:19]}Z")
    rows = [("alias", "spend", "tokens", "requests")]
    for alias in sorted(totals):
        spend, tokens, count = totals[alias]
        rows.append((alias, money(spend), tokens, count))
    rows.append(
        (
            "TOTAL",
            money(sum(value[0] for value in totals.values())),
            sum(value[1] for value in totals.values()),
            sum(value[2] for value in totals.values()),
        )
    )
    render(rows)


def cmd_create(alias, days):
    answer = call(
        "/key/generate",
        {"key_alias": alias, "duration": f"{days}d", "models": MODELS},
    )
    print(f"alias   {answer.get('key_alias')}")
    print(f"expires {answer.get('expires')}")
    print(f"models  {','.join(answer.get('models') or MODELS)}")
    print(f"key     {answer.get('key')}")
    print("the key is shown once; store it now")


def cmd_extend(target, duration):
    answer = call("/key/update", {"key": target_token(target), "duration": duration})
    print(f"{answer.get('key_alias')} now expires {answer.get('expires')}")


def cmd_revoke(target):
    token = target_token(target)
    answer = call("/key/delete", {"keys": [token]})
    print(f"deleted {len(answer.get('deleted_keys') or [])} key(s): {target}")


def main(argv):
    command = argv[1] if len(argv) > 1 else "keys"
    arguments = argv[2:]
    if command in ("-h", "--help", "help"):
        print(USAGE)
    elif command == "keys":
        cmd_keys()
    elif command == "logs":
        count = None
        follow = False
        for token in arguments:
            if token in ("-f", "--follow"):
                follow = True
            elif token.isdigit():
                count = int(token)
            else:
                sys.exit(USAGE)
        cmd_logs(count if count is not None else 20, follow)
    elif command == "totals":
        cmd_totals(int(arguments[0]) if arguments else 7)
    elif command == "create":
        if not arguments:
            sys.exit(USAGE)
        cmd_create(arguments[0], int(arguments[1]) if len(arguments) > 1 else 365)
    elif command == "extend":
        if not arguments:
            sys.exit(USAGE)
        cmd_extend(arguments[0], arguments[1] if len(arguments) > 1 else "365d")
    elif command == "revoke":
        if not arguments:
            sys.exit(USAGE)
        cmd_revoke(arguments[0])
    else:
        sys.exit(USAGE)


if __name__ == "__main__":
    try:
        main(sys.argv)
    except KeyboardInterrupt:
        pass
