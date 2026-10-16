#!/usr/bin/env python3

import argparse
import json
import os
import re
import socket
import subprocess
import sys
import tempfile
import time
import urllib.request

TABLE_URL = "https://opencode.ai/v2/docs/console/go/"
METRIC_PATH = "/var/lib/prometheus-node-textfile-collector/litellm-price-sync.prom"
STATE_PATH = "/var/lib/litellm-price-sync/state.json"
PROXY = "http://127.0.0.1:27015"
CONTAINER = "litellm"
MAX_RATIO = 5.0
MAX_JOBS = "1"
CORES = "2"

LABELS = {
    "beam-free": {
        "flat": "Beam Free",
    },
    "deepseek-v4.1-flash": {
        "peak": "DeepSeek V4.1 Flash (Peak)",
        "offPeak": "DeepSeek V4.1 Flash (Off-Peak)",
    },
    "longcat-2.5-preview-free": {
        "flat": "LongCat 2.5 Preview Free",
    },
    "step-5-preview": {
        "flat": "Step 5 Preview",
    },
}


class Abort(Exception):
    pass


def run(cmd, capture=False, timeout=None):
    result = subprocess.run(
        cmd,
        check=True,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
        timeout=timeout,
    )
    return (result.stdout or "").strip()


def fetch(table):
    if table:
        with open(table, encoding="utf-8") as handle:
            return handle.read()
    request = urllib.request.Request(
        TABLE_URL,
        headers={"Accept": "text/markdown", "User-Agent": "labile-nix-price-sync/1.0"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8")


def go_plan(text):
    start = text.find('<div slot="go">')
    end = text.find('<div slot="go-plus">')
    if start < 0 or end <= start:
        raise Abort("the Go plan table is not where the docs page used to keep it")
    return text[start:end]


def per_token(cell):
    cell = cell.strip().strip("*").strip()
    if cell.lower() == "free":
        return 0.0
    match = re.fullmatch(r"\$([0-9]+(?:\.[0-9]+)?)", cell)
    return None if match is None else float(match.group(1)) / 1e6


def parse_rows(block):
    rows = {}
    for line in block.splitlines():
        line = line.strip()
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if len(cells) < 4:
            continue
        prices = [per_token(cell) for cell in cells[1:4]]
        if any(price is None for price in prices):
            continue
        rows[cells[0]] = {
            "input": prices[0],
            "output": prices[1],
            "cacheRead": prices[2],
        }
    return rows


def row_of(rows, label):
    row = rows.get(label)
    if row is None:
        raise Abort(f"the Go table no longer has the row {label!r}")
    return row


def entry_of(name, rows):
    spec = LABELS.get(name)
    if spec is None:
        raise Abort(f"no OpenCode label mapping for {name}; add one to sync-prices.py")
    if "flat" in spec:
        row = row_of(rows, spec["flat"])
        return {
            "input": row["input"],
            "output": row["output"],
            "cacheRead": row["cacheRead"],
            "offPeak": None,
        }
    peak = row_of(rows, spec["peak"])
    off = row_of(rows, spec["offPeak"])
    return {
        "input": peak["input"],
        "output": peak["output"],
        "cacheRead": peak["cacheRead"],
        "offPeak": {
            "input": off["input"],
            "output": off["output"],
            "cacheRead": off["cacheRead"],
        },
    }


def ratios(name, old, new):
    if old.get("offPeak") is None and new["offPeak"] is not None:
        raise Abort(f"{name}: an off-peak tariff appeared, which needs a human")
    if old.get("offPeak") is not None and new["offPeak"] is None:
        raise Abort(f"{name}: the off-peak tariff disappeared, which needs a human")
    pairs = [
        (f"{name}.{field}", old.get(field, 0.0), new[field])
        for field in ("input", "output", "cacheRead")
    ]
    if new["offPeak"] is not None:
        pairs += [
            (f"{name}.offPeak.{field}", (old.get("offPeak") or {}).get(field, 0.0), new["offPeak"][field])
            for field in ("input", "output", "cacheRead")
        ]
    for field, before, after in pairs:
        if before == after:
            continue
        if before == 0.0 or after == 0.0 or max(after / before, before / after) > MAX_RATIO:
            raise Abort(
                f"{field} moves {before:g} -> {after:g} per token, "
                f"outside the {MAX_RATIO:g}x bound this script is allowed to apply"
            )


def diffs(name, old, new):
    def fmt(value):
        return "none" if value is None else f"{value:g}"

    lines = []
    for field in ("input", "output", "cacheRead"):
        before, after = old.get(field), new[field]
        if before != after:
            lines.append(f"{name}.{field}: {fmt(before)} -> {fmt(after)} per token")
    for field in ("input", "output", "cacheRead"):
        before = (old.get("offPeak") or {}).get(field)
        after = (new["offPeak"] or {}).get(field)
        if before != after:
            lines.append(f"{name}.offPeak.{field}: {fmt(before)} -> {fmt(after)} per token")
    return lines


def git(repo, as_user, *args, capture=False):
    cmd = ["git", "-C", repo, *args]
    if as_user and os.geteuid() == 0:
        cmd = ["runuser", "-u", as_user, "--", "env", f"HOME=/home/{as_user}", *cmd]
    return run(cmd, capture=capture)


def write_prices(repo, groups, entries, as_user):
    path = os.path.join(repo, "modules/litellm/models/prices.json")
    document = {
        "source": TABLE_URL,
        "models": {name: entries[name] for name in sorted(groups)},
    }
    handle, tmp = tempfile.mkstemp(prefix=".prices.json.", dir=os.path.dirname(path))
    with os.fdopen(handle, "w", encoding="utf-8") as out:
        json.dump(document, out, indent=2)
        out.write("\n")
    if as_user and os.geteuid() == 0:
        run(["install", "-o", as_user, "-g", "users", "-m", "0644", tmp, path])
        os.unlink(tmp)
    else:
        os.replace(tmp, path)
    return path


def commit(repo, as_user, message, body):
    git(repo, as_user, "add", "modules/litellm/models/prices.json")
    git(repo, as_user, "commit", "-m", message, "-m", "\n".join(body))
    sha = git(repo, as_user, "rev-parse", "HEAD", capture=True)
    git(repo, as_user, "push")
    return sha


def rebuild(repo):
    run(
        [
            "/run/current-system/sw/bin/nixos-rebuild",
            "switch",
            "--flake",
            f"{repo}#{socket.gethostname()}",
            "--impure",
            "--max-jobs",
            MAX_JOBS,
            "--cores",
            CORES,
            "--show-trace",
        ],
        timeout=7200,
    )


def live_costs():
    key = run(["docker", "exec", CONTAINER, "printenv", "LITELLM_MASTER_KEY"], capture=True)
    request = urllib.request.Request(
        f"{PROXY}/model/info",
        headers={"Authorization": f"Bearer {key}"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        payload = json.load(response)
    live = {}
    for row in payload["data"]:
        params = row["litellm_params"]
        info = row.get("model_info") or {}
        costs = (
            params.get("input_cost_per_token"),
            params.get("output_cost_per_token"),
            params.get("cache_read_input_token_cost"),
        )
        off = info.get("off_peak_pricing")
        off_costs = (
            None
            if not isinstance(off, dict)
            else (
                off.get("input_cost_per_token"),
                off.get("output_cost_per_token"),
                off.get("cache_read_input_token_cost"),
            )
        )
        live.setdefault(row["model_name"], set()).add((costs, off_costs))
    return live


def verify(entries):
    live = live_costs()
    for name, want in entries.items():
        want_off = want["offPeak"]
        expected_off = (
            None
            if want_off is None
            else (want_off["input"], want_off["output"], want_off["cacheRead"])
        )
        expected = ((want["input"], want["output"], want["cacheRead"]), expected_off)
        if live.get(name) != {expected}:
            raise Abort(f"the proxy serves {name} at {live.get(name)}, not at {expected}")


def read_state():
    try:
        with open(STATE_PATH, encoding="utf-8") as handle:
            return json.load(handle)
    except (FileNotFoundError, PermissionError):
        return {"last_success": 0}


def write_state(state):
    os.makedirs(os.path.dirname(STATE_PATH), exist_ok=True)
    with open(STATE_PATH, "w", encoding="utf-8") as handle:
        json.dump(state, handle, indent=2)
        handle.write("\n")


def write_metric(state, changes, error):
    now = int(time.time())
    lines = [
        "# HELP litellm_price_sync_last_run_timestamp_seconds When the price sync last ran.",
        "# TYPE litellm_price_sync_last_run_timestamp_seconds gauge",
        f"litellm_price_sync_last_run_timestamp_seconds {now}",
        "# HELP litellm_price_sync_last_success_timestamp_seconds When the price sync last finished without an error.",
        "# TYPE litellm_price_sync_last_success_timestamp_seconds gauge",
        f"litellm_price_sync_last_success_timestamp_seconds {state.get('last_success', 0)}",
        "# HELP litellm_price_sync_state Current sync outcome, one series is 1.",
        "# TYPE litellm_price_sync_state gauge",
        f'litellm_price_sync_state{{state="{state.get("last_state", "unknown")}"}} 1',
        "# HELP litellm_price_sync_anomaly 1 when the sync refused to apply what the Go table said.",
        "# TYPE litellm_price_sync_anomaly gauge",
        f"litellm_price_sync_anomaly {1 if error else 0}",
        "# HELP litellm_price_sync_change 1 for a model whose price this run changed.",
        "# TYPE litellm_price_sync_change gauge",
    ]
    for name, changed in sorted(changes.items()):
        lines.append(f'litellm_price_sync_change{{model="{name}"}} {1 if changed else 0}')
    lines.append("")
    handle, tmp = tempfile.mkstemp(prefix=".litellm-price-sync.", dir=os.path.dirname(METRIC_PATH))
    with os.fdopen(handle, "w", encoding="utf-8") as out:
        os.fchmod(out.fileno(), 0o644)
        out.write("\n".join(lines))
    os.replace(tmp, METRIC_PATH)


def load_current(repo):
    path = os.path.join(repo, "modules/litellm/models/prices.json")
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)["models"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default="/home/labile/nix")
    parser.add_argument("--groups", help="JSON list of the Zen group names; defaults to the snapshot's keys")
    parser.add_argument("--table", help="read the docs page from a file instead of the network")
    parser.add_argument("--as-user", help="run git and the checkout writes as this user")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--commit", action="store_true")
    parser.add_argument("--push", action="store_true")
    parser.add_argument("--rebuild", action="store_true")
    parser.add_argument("--verify", action="store_true")
    parser.add_argument("--metric", action="store_true")
    args = parser.parse_args()

    current = load_current(args.repo)
    if args.groups:
        with open(args.groups, encoding="utf-8") as handle:
            groups = json.load(handle)
    else:
        groups = sorted(current)
    if not groups:
        print("the group list is empty", file=sys.stderr)
        return 1

    changes = {name: False for name in groups}
    applied = False
    sha = None
    error = None
    try:
        rows = parse_rows(go_plan(fetch(args.table)))
        entries = {name: entry_of(name, rows) for name in groups}
        summary = []
        for name in groups:
            old = current.get(name) or {}
            ratios(name, old, entries[name])
            changes[name] = old != entries[name]
            summary += diffs(name, old, entries[name])
        for line in summary:
            print(line)
        drift = [name for name, changed in changes.items() if changed]
        if not drift:
            print("no drift: every Zen group already matches the Go table")
        elif not args.apply:
            print(f"drift in {', '.join(drift)}; rerun with --apply to write it")
            return 1
        else:
            write_prices(args.repo, groups, entries, args.as_user)
            if args.commit:
                sha = commit(
                    args.repo,
                    args.as_user,
                    "litellm: sync Zen prices from the OpenCode Go table",
                    summary,
                )
            if args.push and not args.commit:
                raise Abort("--push without --commit has nothing to push")
            applied = True
            print(f"applied: {', '.join(drift)}")
    except Abort as failure:
        error = str(failure)
        print(f"refusing to apply: {error}", file=sys.stderr)
    except Exception as failure:
        error = f"{type(failure).__name__}: {failure}"
        print(f"failed: {error}", file=sys.stderr)

    if error is None and applied and args.rebuild:
        try:
            rebuild(args.repo)
            print("rebuilt")
            if args.verify:
                verify({name: load_current(args.repo)[name] for name in groups})
                print("verified: the proxy serves the new costs")
        except Exception as failure:
            error = f"{type(failure).__name__}: {failure}"
            print(f"the applied prices are not live: {error}", file=sys.stderr)
            if sha:
                try:
                    git(args.repo, args.as_user, "revert", "--no-edit", sha)
                    git(args.repo, args.as_user, "push")
                    rebuild(args.repo)
                    print("reverted and rebuilt")
                except Exception as rollback:
                    print(f"the revert itself failed: {rollback}", file=sys.stderr)

    state = read_state()
    state["last_state"] = "failed" if error else ("changed" if applied else "ok")
    if error is None:
        state["last_success"] = int(time.time())
        state["last_error"] = ""
    else:
        state["last_error"] = error
    if args.metric:
        try:
            write_state(state)
            write_metric(state, changes, error)
        except OSError as failure:
            print(f"could not publish the sync state: {failure}", file=sys.stderr)
            error = error or f"{type(failure).__name__}: {failure}"
            return 1
    return 1 if error else 0


if __name__ == "__main__":
    sys.exit(main())
