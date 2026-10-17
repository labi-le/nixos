#!/usr/bin/env python3
import argparse
import json
import os
import sys
import tempfile
import time
import urllib.error
import urllib.request

PROXY = os.environ.get("LITELLM_FREE_PROBE_PROXY", "http://127.0.0.1:27015")
ENV_PATH = os.environ.get("LITELLM_FREE_PROBE_ENV_PATH", "/run/agenix/litellm-env")
METRIC_PATH = os.environ.get(
    "LITELLM_FREE_PROBE_METRIC_PATH",
    "/var/lib/prometheus-node-textfile-collector/litellm-free-probe.prom",
)
STATE_PATH = os.environ.get(
    "LITELLM_FREE_PROBE_STATE_PATH",
    "/var/lib/litellm-free-probe/state.json",
)
TIMEOUT = 60
TARGETS = {
    "deepseek-v4.1-flash-free": "chat",
    "space-bunny-free": "chat",
    "muse-spark-1.2-contributor-free": "responses",
}


def master_key():
    key = os.environ.get("LITELLM_MASTER_KEY")
    if key:
        return key
    with open(ENV_PATH, encoding="utf-8") as handle:
        for line in handle:
            name, _, value = line.strip().partition("=")
            if name == "LITELLM_MASTER_KEY":
                return value
    raise SystemExit(f"no LITELLM_MASTER_KEY in {ENV_PATH}")


def request_body(route, model, stream):
    if route == "responses":
        return {"model": model, "input": "ping", "max_output_tokens": 16, "stream": stream}
    return {
        "model": model,
        "messages": [{"role": "user", "content": "ping"}],
        "max_tokens": 16,
        "stream": stream,
    }


def endpoint(route):
    return "/v1/responses" if route == "responses" else "/v1/chat/completions"


def classify(status, body):
    text = body.lower()
    if status == 403 and "free tier" in text:
        return "gate"
    if status == 410 or "modeldeprecated" in text:
        return "deprecated"
    if status == 429:
        return "quota"
    if status == 400 and "modelprotocolunsupported" in text:
        return "protocol"
    if 500 <= status <= 599:
        return "upstream"
    return "http"


def probe(key, model, route, stream, timeout):
    data = json.dumps(request_body(route, model, stream)).encode()
    headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}
    request = urllib.request.Request(PROXY + endpoint(route), data=data, headers=headers)
    started = time.time()
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read().decode("utf-8", "replace")
            latency = time.time() - started
            events = 0
            for line in body.splitlines():
                if not line.startswith("data: "):
                    continue
                chunk = line[6:].strip()
                if not chunk or chunk == "[DONE]":
                    continue
                try:
                    json.loads(chunk)
                except ValueError:
                    continue
                events += 1
            if stream and events == 0:
                return "empty", latency, f"the stream carried no event: {body[:400]}"
            return "ok", latency, ""
    except urllib.error.HTTPError as failure:
        body = failure.read().decode("utf-8", "replace")
        return classify(failure.code, body), time.time() - started, f"HTTP {failure.code}: {body[:800]}"
    except Exception as failure:
        return "network", time.time() - started, f"{type(failure).__name__}: {failure}"


def write_metric(lines):
    directory = os.path.dirname(METRIC_PATH)
    os.makedirs(directory, exist_ok=True)
    handle, tmp = tempfile.mkstemp(prefix=".litellm-free-probe.", dir=directory)
    with os.fdopen(handle, "w", encoding="utf-8") as out:
        os.fchmod(out.fileno(), 0o644)
        out.write("\n".join(lines) + "\n")
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
        json.dump(state, handle, indent=2, sort_keys=True)
        handle.write("\n")


def exposition(records, run_stamp):
    label = lambda name: "{" + f"model={json.dumps(name)}" + "}"
    lines = [
        "# HELP litellm_free_probe_ok 1 when a streaming request to the group answered through the gateway.",
        "# TYPE litellm_free_probe_ok gauge",
    ]
    for model, record in sorted(records.items()):
        state = json.dumps(record["state"])
        lines.append(f'litellm_free_probe_ok{{model={json.dumps(model)},state={state}}} {1 if record["state"] == "ok" else 0}')
    lines.extend(
        [
            "# HELP litellm_free_probe_latency_seconds Time from the gateway request to its first full body.",
            "# TYPE litellm_free_probe_latency_seconds gauge",
            "# HELP litellm_free_probe_last_success_timestamp_seconds Last run in which the group answered.",
            "# TYPE litellm_free_probe_last_success_timestamp_seconds gauge",
            "# HELP litellm_free_probe_checked_timestamp_seconds Last run that probed the group.",
            "# TYPE litellm_free_probe_checked_timestamp_seconds gauge",
            "# HELP litellm_free_probe_run_timestamp_seconds Last run of the probe itself.",
            "# TYPE litellm_free_probe_run_timestamp_seconds gauge",
        ]
    )
    for model, record in sorted(records.items()):
        lines.append(f"litellm_free_probe_latency_seconds{label(model)} {record['latency_seconds']:.3f}")
        lines.append(f"litellm_free_probe_last_success_timestamp_seconds{label(model)} {record['last_success']}")
        lines.append(f"litellm_free_probe_checked_timestamp_seconds{label(model)} {record['checked']}")
    lines.append(f"litellm_free_probe_run_timestamp_seconds {run_stamp}")
    return lines


def ready(timeout):
    deadline = time.time() + timeout
    url = PROXY + "/health/readiness"
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=5) as response:
                if response.status == 200:
                    return True
        except Exception:
            pass
        time.sleep(3)
    return False


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--stdout", action="store_true", help="print the exposition instead of writing it")
    parser.add_argument("--model", action="append", help="probe one group instead of every group")
    parser.add_argument("--no-stream", action="store_true", help="send a non-streaming request, which the free tier refuses")
    parser.add_argument("--timeout", type=float, default=TIMEOUT)
    parser.add_argument("--wait", type=float, default=300, help="how long to wait for the gateway to become ready")
    args = parser.parse_args()

    key = master_key()
    models = args.model or list(TARGETS)
    previous = read_state()
    records = {}
    run_stamp = int(time.time())
    reachable = ready(args.wait)
    for model in models:
        route = TARGETS.get(model, "chat")
        if reachable:
            state, latency, detail = probe(key, model, route, not args.no_stream, args.timeout)
        else:
            state, latency, detail = "network", 0.0, f"the gateway did not answer /health/readiness within {args.wait:.0f}s"
        keep = previous.get(model) or {}
        records[model] = {
            "state": state,
            "latency_seconds": round(latency, 3),
            "detail": detail,
            "last_success": run_stamp if state == "ok" else keep.get("last_success", 0),
            "checked": run_stamp,
        }
        note = f" ({detail[:300]})" if detail else ""
        print(f"{model}: {state} in {latency:.2f}s{note}", file=sys.stderr)

    lines = exposition(records, run_stamp)
    if args.stdout:
        print("\n".join(lines))
        return 0
    if not args.model:
        write_metric(lines)
        merged = dict(previous)
        merged.update(records)
        write_state(merged)
    return 0


if __name__ == "__main__":
    sys.exit(main())
