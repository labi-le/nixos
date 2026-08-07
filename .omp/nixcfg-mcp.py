#!/usr/bin/env python3

import fnmatch
import json
import os
import re
import subprocess
import sys
import threading
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
ROUTES = REPO / "docs" / "routes.md"
LOCK = REPO / "flake.lock"
HOSTS = ("pc", "fx516", "notebook", "server")
NIXOS_REBUILD = "/run/current-system/sw/bin/nixos-rebuild"
NIX_COLLECT_GARBAGE = "/run/current-system/sw/bin/nix-collect-garbage"
SYSTEM_PROFILES = Path("/nix/var/nix/profiles")
PROTOCOLS = ("2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05")
LATEST_PROTOCOL = "2025-06-18"
SERVER_INFO = {"name": "nixcfg", "title": "NixOS config operations", "version": "1.0.0"}
INSTRUCTIONS = (
    "Maintenance tools for the NixOS flake at "
    f"{REPO}. Rebuild, verify, roll back and route module edits. "
    "Use the `nixos` MCP server for package/option documentation instead."
)
STATE = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local" / "state") / "nixcfg-mcp"
JOBS = STATE / "jobs"
MAX_TEXT = 20000
SHORT_TIMEOUT = 180
OWNER = Path.home().name
MAX_JOBS = 40
LOG_TAIL_BYTES = 256 * 1024
STOP_WORDS = frozenset(
    "the and for with from into that this how where add use set new when only "
    "change edit configure enable disable make host hosts file files module modules".split()
)
PATH_CELL_RE = re.compile(r"`([^`]+)`")
PATH_SHAPE_RE = re.compile(r"^[\w./@<>*+-]+\.(nix|ya?ml|age|json|jar|lock|patch|py|md)$")
DELIMITER_RE = re.compile(r"^\|[\s\-:|]+\|$")
DIRTY_WARNING_RE = re.compile(r"Git tree '.*' is dirty")
BUILT_RE = re.compile(r"these (\d+) derivations will be built")
FETCH_RE = re.compile(r"these (\d+) paths will be fetched")
DRV_FAIL_RE = re.compile(r"builder for '(/nix/store/\S+\.drv)' failed|error: build of '(\S+)' failed")
FREED_RE = re.compile(r"(\d+) store paths deleted, (.+) freed")
WOULD_DELETE_RE = re.compile(r"(\d+) store paths would be deleted")

OUT_LOCK = threading.Lock()
CANCELLED = set()
JOB_CHILDREN = {}
MISSING_ATTR_RE = re.compile(r"attribute '[^']+' missing|does not provide attribute")
ROUTES_CACHE = {"mtime": None, "sections": None, "rows": None, "idf": None}


class ToolError(Exception):
    pass


def emit(message):
    with OUT_LOCK:
        sys.stdout.write(json.dumps(message, separators=(",", ":")) + "\n")
        sys.stdout.flush()


def reply(request_id, result):
    emit({"jsonrpc": "2.0", "id": request_id, "result": result})


def fail(request_id, code, message):
    emit({"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message}})


def progress(token, step, message):
    if token is None:
        return
    emit(
        {
            "jsonrpc": "2.0",
            "method": "notifications/progress",
            "params": {"progressToken": token, "progress": step, "message": message[:200]},
        }
    )


def run(argv, timeout=SHORT_TIMEOUT, cwd=None):
    try:
        done = subprocess.run(
            argv,
            cwd=str(cwd or REPO),
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
        )
    except FileNotFoundError:
        raise ToolError(f"executable not found: {argv[0]}")
    except subprocess.TimeoutExpired:
        raise ToolError(f"timed out after {timeout}s: {' '.join(argv)}")
    return done.returncode, done.stdout.decode("utf-8", "replace")


def run_split(argv, timeout=SHORT_TIMEOUT, cwd=None):
    try:
        done = subprocess.run(
            argv,
            cwd=str(cwd or REPO),
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
        )
    except FileNotFoundError:
        raise ToolError(f"executable not found: {argv[0]}")
    except subprocess.TimeoutExpired:
        raise ToolError(f"timed out after {timeout}s: {' '.join(argv)}")
    return (
        done.returncode,
        done.stdout.decode("utf-8", "replace"),
        done.stderr.decode("utf-8", "replace"),
    )


def nix_noise(text):
    return "\n".join(
        line
        for line in text.splitlines()
        if line.strip()
        and not DIRTY_WARNING_RE.search(line)
        and not line.startswith("error (ignored):")
    )


def tail(text, lines):
    kept = text.splitlines()[-lines:]
    return "\n".join(kept)


def clamp(text):
    if len(text) <= MAX_TEXT:
        return text
    return "[truncated to the last %d chars]\n" % MAX_TEXT + text[-MAX_TEXT:]


def envelope(header, body=""):
    text = json.dumps(header, indent=2, ensure_ascii=False)
    if body:
        text += "\n\n" + body
    return clamp(text)


def cores():
    return str(os.cpu_count() or 1)


def current_host():
    return os.uname().nodename


def require_host(args, default_current=True):
    host = args.get("host") or (current_host() if default_current else None)
    if host not in HOSTS:
        raise ToolError(f"unknown host {host!r}; expected one of {', '.join(HOSTS)}")
    return host


def untracked_nix():
    code, out = run(
        ["git", "status", "--porcelain", "-z", "--untracked-files=all"], timeout=60
    )
    if code != 0:
        return []
    return [
        entry[3:]
        for entry in out.split("\0")
        if entry.startswith("?? ") and entry.endswith(".nix")
    ]


def first_error(text):
    lines = text.splitlines()
    for index, line in enumerate(lines):
        if line.lstrip().startswith("error:"):
            return "\n".join(lines[index : index + 30])
    return None


def failed_derivation(text):
    match = DRV_FAIL_RE.search(text)
    if not match:
        return None
    return match.group(1) or match.group(2)


def job_dir():
    JOBS.mkdir(parents=True, exist_ok=True)
    return JOBS


def job_meta_path(job):
    return job_dir() / f"{job}.json"


def job_log_path(job):
    return job_dir() / f"{job}.log"


def allocate_job(action):
    base = "%s-%s" % (action.replace("-", "_"), time.strftime("%Y%m%d-%H%M%S"))
    job = base
    suffix = 1
    while True:
        try:
            os.close(os.open(str(job_log_path(job)), os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o644))
            return job
        except FileExistsError:
            suffix += 1
            job = f"{base}-{suffix}"


def job_rc_path(job):
    return job_dir() / f"{job}.rc"


def start_job(action, argv):
    job = allocate_job(action)
    log = job_log_path(job)
    handle = open(log, "wb")
    handle.write(("$ " + " ".join(argv) + "\n").encode())
    handle.flush()
    wrapped = [
        "/bin/sh",
        "-c",
        'rc=0; "$@" || rc=$?; printf %s "$rc" > "$0"; exit "$rc"',
        str(job_rc_path(job)),
    ] + argv
    child = subprocess.Popen(
        wrapped,
        cwd=str(REPO),
        stdin=subprocess.DEVNULL,
        stdout=handle,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    handle.close()
    meta = {
        "job": job,
        "action": action,
        "command": argv,
        "pid": child.pid,
        "log": str(log),
        "started": time.strftime("%Y-%m-%d %H:%M:%S"),
        "state": "running",
    }
    job_meta_path(job).write_text(json.dumps(meta, indent=2))
    JOB_CHILDREN[job] = child
    return child, meta


def finish_job(meta, code, seconds):
    meta["state"] = "exited" if code is not None else "detached"
    meta["exit_code"] = code
    meta["duration_s"] = round(seconds, 1)
    job_meta_path(meta["job"]).write_text(json.dumps(meta, indent=2))
    return meta


def process_alive(pid):
    try:
        fields = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[-1].split()
    except OSError:
        return False
    return bool(fields) and fields[0] != "Z"


def recorded_exit_code(job):
    try:
        return int(job_rc_path(job).read_text().strip())
    except (OSError, ValueError):
        return None


def refresh_job(meta):
    if meta.get("state") not in ("running", "detached"):
        return meta
    job = meta["job"]
    child = JOB_CHILDREN.get(job)
    if child is not None and child.poll() is None:
        return meta
    recorded = recorded_exit_code(job)
    if recorded is not None:
        meta["state"] = "exited"
        meta["exit_code"] = recorded
    elif child is not None:
        meta["state"] = "exited"
        meta["exit_code"] = child.returncode
    elif meta.get("pid") and not process_alive(meta["pid"]):
        meta["state"] = "finished"
        meta["exit_code_note"] = "process is gone and wrote no exit code; read the log tail"
    else:
        return meta
    job_meta_path(job).write_text(json.dumps(meta, indent=2))
    return meta


def await_job(child, meta, wait_s, request_id, token):
    started = time.monotonic()
    step = 0
    while True:
        code = child.poll()
        if code is not None:
            return code, time.monotonic() - started
        if str(request_id) in CANCELLED:
            return None, time.monotonic() - started
        if time.monotonic() - started >= wait_s:
            return None, time.monotonic() - started
        time.sleep(1.0)
        step += 1
        if token is not None and step % 5 == 0:
            progress(token, step, tail(read_log(meta["job"]), 1) or meta["action"])


def read_log(job, limit=LOG_TAIL_BYTES):
    path = job_log_path(job)
    if not path.exists():
        return ""
    size = path.stat().st_size
    with path.open("rb") as handle:
        if size > limit:
            handle.seek(size - limit)
        chunk = handle.read()
    text = chunk.decode("utf-8", "replace")
    if size > limit:
        return "[log truncated to the last %d bytes of %d]\n" % (limit, size) + text
    return text


def known_jobs():
    if not JOBS.exists():
        return []
    metas = []
    for path in sorted(JOBS.glob("*.json"))[-MAX_JOBS:]:
        try:
            metas.append(json.loads(path.read_text()))
        except ValueError:
            continue
    metas.sort(key=lambda meta: meta.get("started", ""))
    return metas


def failed_units():
    system = run(["systemctl", "--failed", "--no-legend", "--plain", "--no-pager"], timeout=60)[1]
    user = run(
        ["systemctl", "--user", "--failed", "--no-legend", "--plain", "--no-pager"], timeout=60
    )[1]
    parse = lambda text: [line.split()[0] for line in text.splitlines() if line.strip()]
    return {"system": parse(system), "user": parse(user)}


def rebuild_argv(action, host):
    flake = f"./#{host}"
    if action == "build":
        return [NIXOS_REBUILD, "build", "--flake", flake, "--impure", "--cores", cores(), "--no-link"]
    argv = ["sudo", "-n", NIXOS_REBUILD, action, "--flake", flake, "--impure", "--cores", cores()]
    if action == "boot":
        return argv + ["--install-bootloader"]
    return argv + ["--show-trace"]


def tool_rebuild(args, request_id, token):
    action = args.get("action") or "switch"
    if action not in ("switch", "boot", "test", "dry-activate", "build"):
        raise ToolError(f"unknown action {action!r}")
    host = require_host(args)
    if action != "build" and host != current_host():
        raise ToolError(
            f"refusing to {action} host {host!r} from {current_host()!r}; "
            "use action=build to only verify another host's configuration"
        )
    stray = untracked_nix()
    if stray and not args.get("allow_untracked"):
        raise ToolError(
            "untracked .nix files are invisible to the flake and would be silently omitted: "
            + ", ".join(stray)
            + ". Run `make fix-flake` (git add --intent-to-add .) or pass allow_untracked=true."
        )
    wait_s = max(1, min(int(args.get("wait_s") or 1800), 7200))
    argv = rebuild_argv(action, host)
    child, meta = start_job(action, argv)
    code, seconds = await_job(child, meta, wait_s, request_id, token)
    finish_job(meta, code, seconds)
    log = read_log(meta["job"])
    header = {
        "action": action,
        "host": host,
        "command": " ".join(argv),
        "job": meta["job"],
        "log": meta["log"],
        "state": meta["state"],
        "exit_code": code,
        "duration_s": meta["duration_s"],
        "untracked_nix": stray,
    }
    if code is None:
        header["note"] = (
            f"still running as pid {meta['pid']} (detached from this server); "
            f"poll with rebuild_log job={meta['job']}"
        )
        return envelope(header, tail(log, 40)), False
    if code == 0:
        if action in ("switch", "boot", "test"):
            header["failed_units"] = failed_units()
        built = re.search(r"The new configuration is (/nix/store/\S+)", log)
        if built:
            header["toplevel"] = built.group(1)
            header["no_gc_root"] = action == "build"
        return envelope(header, tail(log, 25)), False
    header["first_error"] = first_error(log)
    header["failed_derivation"] = failed_derivation(log)
    return envelope(header, tail(log, 120)), True


def tool_rebuild_log(args, request_id, token):
    metas = known_jobs()
    if not metas:
        return envelope({"jobs": [], "note": "no rebuild has been started by this server yet"}), False
    job = args.get("job")
    if job:
        selected = next((meta for meta in metas if meta["job"] == job), None)
        if selected is None:
            raise ToolError(f"unknown job {job!r}; known jobs: {', '.join(m['job'] for m in metas)}")
    else:
        selected = metas[-1]
    refresh_job(selected)
    lines = max(1, min(int(args.get("lines") or 80), 2000))
    log = read_log(selected["job"])
    pattern = args.get("grep")
    if pattern:
        try:
            matcher = re.compile(pattern)
        except re.error as error:
            raise ToolError(f"invalid grep pattern: {error}")
        log = "\n".join(line for line in log.splitlines() if matcher.search(line))
    header = {
        "job": selected["job"],
        "action": selected.get("action"),
        "state": selected.get("state"),
        "exit_code": selected.get("exit_code"),
        "duration_s": selected.get("duration_s"),
        "log": selected.get("log"),
        "jobs": [meta["job"] for meta in metas[-10:]],
    }
    return envelope(header, tail(log, lines)), False


def tool_dry_run(args, request_id, token):
    host = require_host(args)
    attribute = f".#nixosConfigurations.{host}.config.system.build.toplevel"
    argv = ["nix", "build", attribute, "--dry-run"]
    stray = untracked_nix()
    code, out = run(argv, timeout=1800)
    warnings = [
        line
        for line in out.splitlines()
        if line.startswith("warning:") and not DIRTY_WARNING_RE.search(line)
    ]
    built = BUILT_RE.search(out)
    fetched = FETCH_RE.search(out)
    header = {
        "host": host,
        "command": " ".join(argv),
        "exit_code": code,
        "verdict": "pass" if code == 0 and not warnings else "fail",
        "gate": "exit 0 and no evaluation or deprecation warnings; 'Git tree is dirty' excluded",
        "warnings": warnings,
        "derivations_to_build": int(built.group(1)) if built else (1 if "this derivation will be built" in out else 0),
        "paths_to_fetch": int(fetched.group(1)) if fetched else 0,
        "untracked_nix": stray,
    }
    if code != 0:
        header["first_error"] = first_error(out)
    return envelope(header, tail(out, 80)), code != 0


def eval_prelude(host):
    return (
        f"let flake = builtins.getFlake (toString {REPO});"
        " hosts = builtins.attrNames flake.nixosConfigurations;"
        " configs = builtins.mapAttrs (_: system: system.config) flake.nixosConfigurations;"
        f" config = flake.nixosConfigurations.{host}.config;"
        f" options = flake.nixosConfigurations.{host}.options;"
        f" pkgs = flake.nixosConfigurations.{host}.pkgs;"
        " lib = flake.inputs.nixpkgs.lib;"
        f" hm = flake.nixosConfigurations.{host}.config.home-manager.users.{OWNER} or null;"
        " in "
    )


def eval_target(attr, host):
    if "#" in attr:
        return attr
    if attr.startswith("options."):
        return f".#nixosConfigurations.{host}.{attr}"
    if attr.startswith("hm."):
        return (
            f".#nixosConfigurations.{host}.config.home-manager.users.{OWNER}.{attr[3:]}"
        )
    return f".#nixosConfigurations.{host}.config.{attr}"


def attr_candidates(target):
    path = target
    for _ in range(5):
        parent, dot, leaf = path.rpartition(".")
        if not dot:
            return None
        code, out, _ = run_split(
            ["nix", "eval", parent, "--apply", "builtins.attrNames", "--json"], timeout=600
        )
        if code == 0:
            try:
                names = json.loads(out)
            except ValueError:
                return None
            if not isinstance(names, list):
                return None
            return {"missing": leaf, "resolved_parent": parent, "available": sorted(names)[:80]}
        path = parent
    return None


def tool_eval(args, request_id, token):
    attr = (args.get("attr") or "").strip()
    expr = (args.get("expr") or "").strip()
    if bool(attr) == bool(expr):
        raise ToolError("pass exactly one of attr or expr")
    host = require_host(args)
    raw = bool(args.get("raw"))
    if expr:
        target = None
        base = ["nix", "eval", "--impure", "--expr", eval_prelude(host) + expr]
    else:
        target = eval_target(attr, host)
        base = ["nix", "eval", target]
        if args.get("apply"):
            base += ["--apply", args["apply"]]
    argv = base + (["--raw"] if raw else ["--json"])
    code, out, err = run_split(argv, timeout=1800)
    fmt = "raw" if raw else "json"
    if code != 0 and not raw:
        code2, out2, err2 = run_split(base, timeout=1800)
        if code2 == 0:
            code, out, err, fmt = code2, out2, err2, "nix"
    header = {
        "target": target or "--expr",
        "host": host,
        "format": fmt,
        "exit_code": code,
    }
    if expr:
        header["bindings"] = "flake hosts configs config options pkgs lib hm"
    if code != 0:
        header["error"] = tail(nix_noise(err), 25)
        if target and MISSING_ATTR_RE.search(err):
            candidates = attr_candidates(target)
            if candidates:
                header["candidates"] = candidates
        return envelope(header), True
    noise = nix_noise(err)
    if noise:
        header["stderr"] = tail(noise, 10)
    if fmt == "json":
        try:
            header["value"] = json.loads(out)
            return envelope(header), False
        except ValueError:
            pass
    return envelope(header, clamp(out.rstrip("\n"))), False


def tool_generations(args, request_id, token):
    limit = max(1, min(int(args.get("limit") or 10), 100))
    code, out = run([NIXOS_REBUILD, "list-generations", "--json"], timeout=120)
    if code != 0:
        raise ToolError(f"list-generations failed with {code}:\n{tail(out, 20)}")
    try:
        entries = json.loads(out)
    except ValueError:
        raise ToolError(f"unparseable list-generations output:\n{tail(out, 20)}")
    return envelope({"count": len(entries), "generations": entries[:limit]}), False


def tool_rollback(args, request_id, token):
    if args.get("confirm") != "yes":
        raise ToolError("rollback activates the previous generation; pass confirm=\"yes\"")
    argv = ["sudo", "-n", NIXOS_REBUILD, "switch", "--rollback"]
    child, meta = start_job("rollback", argv)
    code, seconds = await_job(child, meta, 900, request_id, token)
    finish_job(meta, code, seconds)
    log = read_log(meta["job"])
    header = {
        "command": " ".join(argv),
        "job": meta["job"],
        "state": meta["state"],
        "exit_code": code,
        "duration_s": meta["duration_s"],
    }
    if code == 0:
        header["failed_units"] = failed_units()
    elif code is not None:
        header["first_error"] = first_error(log)
    return envelope(header, tail(log, 60)), bool(code)


def generation_link(number):
    link = SYSTEM_PROFILES / f"system-{number}-link"
    if not link.exists():
        raise ToolError(f"no such system generation: {number}")
    return str(link)


def tool_diff_generations(args, request_id, token):
    code, out = run([NIXOS_REBUILD, "list-generations", "--json"], timeout=120)
    if code != 0:
        raise ToolError(f"list-generations failed with {code}:\n{tail(out, 20)}")
    try:
        entries = json.loads(out)
    except ValueError:
        raise ToolError(f"unparseable list-generations output:\n{tail(out, 20)}")
    numbers = [entry["generation"] for entry in entries]
    left = args.get("from")
    right = args.get("to")
    if right is None:
        right = next((entry["generation"] for entry in entries if entry.get("current")), numbers[0])
    if left is None:
        remaining = [number for number in numbers if number < right]
        if not remaining:
            raise ToolError(f"no generation older than {right} to compare against")
        left = max(remaining)
    argv = ["nix", "store", "diff-closures", generation_link(left), generation_link(right)]
    code, out = run(argv, timeout=600)
    header = {"from": left, "to": right, "command": " ".join(argv), "exit_code": code}
    return envelope(header, tail(out, 400)), code != 0


def generation_count():
    code, out = run([NIXOS_REBUILD, "list-generations", "--json"], timeout=120)
    if code != 0:
        return None
    try:
        return len(json.loads(out))
    except ValueError:
        return None


def require_passwordless(binary):
    code, out = run(["sudo", "-n", binary, "--version"], timeout=30)
    if code != 0:
        raise ToolError(
            f"passwordless sudo for {binary} is not active: {tail(out, 1).strip()}. "
            "The rule lives in modules/sudo.nix and takes effect only after `make switch`."
        )


def tool_gc(args, request_id, token):
    mode = args.get("mode") or "full"
    preview = bool(args.get("dry_run"))
    if mode not in ("full", "older_than"):
        raise ToolError(f"unknown mode {mode!r}; expected full or older_than")
    flags = ["-d"]
    if mode == "older_than":
        days = args.get("days")
        if days is None:
            raise ToolError("mode=older_than requires days")
        days = int(days)
        if days < 1:
            raise ToolError(f"days must be at least 1, got {days}")
        flags = ["--delete-older-than", f"{days}d"]
    if preview:
        flags.append("--dry-run")
    elif args.get("confirm") != "yes":
        raise ToolError(
            "garbage collection irreversibly deletes old generations and makes rollbacks to "
            "them impossible; pass confirm=\"yes\", or dry_run=true to preview"
        )
    require_passwordless(NIX_COLLECT_GARBAGE)
    before = generation_count()
    argv = ["sudo", "-n", NIX_COLLECT_GARBAGE] + flags
    child, meta = start_job("gc", argv)
    code, seconds = await_job(child, meta, max(1, min(int(args.get("wait_s") or 1800), 7200)), request_id, token)
    finish_job(meta, code, seconds)
    log = read_log(meta["job"])
    header = {
        "mode": mode,
        "dry_run": preview,
        "command": " ".join(argv),
        "job": meta["job"],
        "state": meta["state"],
        "exit_code": code,
        "duration_s": meta["duration_s"],
        "generations_before": before,
    }
    if code is None:
        header["note"] = (
            f"still running as pid {meta['pid']} (detached from this server); "
            f"poll with rebuild_log job={meta['job']}"
        )
        return envelope(header, tail(log, 20)), False
    if code != 0:
        header["first_error"] = first_error(log)
        return envelope(header, tail(log, 60)), True
    freed = FREED_RE.search(log)
    would = WOULD_DELETE_RE.search(log)
    if freed:
        header["store_paths_deleted"] = int(freed.group(1))
        header["freed"] = freed.group(2)
    elif would:
        header["store_paths_would_be_deleted"] = int(would.group(1))
    if not preview:
        after = generation_count()
        header["generations_after"] = after
        if before is not None and after is not None:
            header["generations_deleted"] = before - after
    return envelope(header, tail(log, 20)), False


def lock_revisions(lock):
    return {
        name: node.get("locked", {})
        for name, node in lock.get("nodes", {}).items()
        if name != lock.get("root")
    }


def tool_flake_update(args, request_id, token):
    if args.get("confirm") != "yes":
        raise ToolError("nix flake update rewrites flake.lock; pass confirm=\"yes\"")
    inputs = args.get("inputs") or []
    if isinstance(inputs, str):
        inputs = [inputs]
    before = json.loads(LOCK.read_text())
    argv = ["nix", "flake", "update"] + list(inputs)
    child, meta = start_job("flake_update", argv)
    code, seconds = await_job(child, meta, max(1, min(int(args.get("wait_s") or 900), 3600)), request_id, token)
    finish_job(meta, code, seconds)
    log = read_log(meta["job"])
    header = {
        "command": " ".join(argv),
        "job": meta["job"],
        "state": meta["state"],
        "exit_code": code,
        "duration_s": meta["duration_s"],
    }
    if code is None:
        header["note"] = (
            f"still running as pid {meta['pid']} (detached from this server); "
            f"poll with rebuild_log job={meta['job']}"
        )
        return envelope(header, tail(log, 20)), False
    if code != 0:
        header["first_error"] = first_error(log)
        return envelope(header, tail(log, 80)), True
    after = json.loads(LOCK.read_text())
    old = lock_revisions(before)
    new = lock_revisions(after)
    changes = []
    for name, locked in sorted(new.items()):
        previous = old.get(name, {})
        if previous.get("rev") != locked.get("rev"):
            changes.append(
                {
                    "node": name,
                    "old_rev": (previous.get("rev") or "")[:10] or None,
                    "new_rev": (locked.get("rev") or "")[:10] or None,
                    "new_date": iso(locked.get("lastModified")),
                }
            )
    header["changed_nodes"] = changes
    header["next"] = "verify with dry_run, then rebuild action=switch"
    return envelope(header, tail(log, 40)), False


def iso(stamp):
    if not stamp:
        return None
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(stamp))


def resolve_input_node(lock, reference):
    if isinstance(reference, str):
        return reference
    node = lock["root"]
    for part in reference:
        node = lock["nodes"][node]["inputs"][part]
        if isinstance(node, list):
            node = resolve_input_node(lock, node)
    return node


def tool_flake_age(args, request_id, token):
    name = args.get("input") or "nixpkgs"
    lock = json.loads(LOCK.read_text())
    root_inputs = lock["nodes"][lock["root"]]["inputs"]
    if name not in root_inputs:
        raise ToolError(
            f"{name!r} is not a root flake input; available: {', '.join(sorted(root_inputs))}"
        )
    node = resolve_input_node(lock, root_inputs[name])
    locked = lock["nodes"][node].get("locked", {})
    stamp = locked.get("lastModified")
    header = {
        "input": name,
        "node": node,
        "rev": locked.get("rev"),
        "date": iso(stamp),
        "age_days": round((time.time() - stamp) / 86400.0, 1) if stamp else None,
        "note": f"resolved via .nodes[.root].inputs.{name}; a node literally named "
        f"{name!r} may be an unrelated transitive copy",
        "update_command": f"nix flake update {name}",
    }
    if args.get("with_commit", True) and locked.get("rev"):
        code, out = run(
            ["git", "log", "-1", "--format=%ci %h %s", "-S", locked["rev"], "--", "flake.lock"],
            timeout=120,
        )
        header["bumped_in_repo"] = out.strip() or None if code == 0 else None
    return envelope(header), False


def journal_entries(text):
    return [
        line
        for line in text.splitlines()
        if line.strip() and not line.startswith("--")
    ]


def tool_health(args, request_id, token):
    header = {"failed_units": failed_units()}
    body = ""
    unit = args.get("unit")
    if unit:
        lines = str(max(1, min(int(args.get("lines") or 60), 1000)))
        code, out = run(
            ["journalctl", "-u", unit, "-n", lines, "--no-pager", "-o", "short-iso"], timeout=120
        )
        if code != 0 or not journal_entries(out):
            code, out = run(
                ["journalctl", "--user-unit", unit, "-n", lines, "--no-pager", "-o", "short-iso"],
                timeout=120,
            )
            header["scope"] = "user"
        else:
            header["scope"] = "system"
        header["unit"] = unit
        header["journal_exit_code"] = code
        header["journal_empty"] = not journal_entries(out)
        body = tail(out, int(lines))
    return envelope(header, body), False


def split_row(line):
    cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
    return cells


def section_hosts(heading, cell_text):
    lowered = heading.lower()
    if lowered.startswith("pc-specific"):
        return ["pc"]
    if lowered.startswith("fx516-specific"):
        return ["fx516"]
    if lowered.startswith("notebook-specific"):
        return ["notebook"]
    if lowered.startswith("server-specific"):
        return ["server"]
    if lowered.startswith("home manager") or lowered.startswith("desktop-only"):
        found = [host for host in HOSTS if host != "server" and host in cell_text]
        return found or ["pc", "fx516", "notebook"]
    return list(HOSTS)


def extract_paths(cell):
    paths = []
    for token in PATH_CELL_RE.findall(cell or ""):
        token = token.strip()
        if not (PATH_SHAPE_RE.match(token) or token == "Makefile"):
            continue
        entry = {"path": token}
        if "<" in token:
            entry["placeholder"] = True
        if "*" in token:
            entry["glob"] = True
        if token.startswith(("~", "/")):
            entry["outside_repo"] = True
        if "/" not in token and token != "Makefile":
            entry["bare_name"] = True
        unresolvable = entry.get("placeholder") or entry.get("glob") or entry.get("outside_repo")
        entry["exists"] = None if unresolvable else (REPO / token).exists()
        paths.append(entry)
    return paths


def parse_routes():
    mtime = ROUTES.stat().st_mtime
    if ROUTES_CACHE["mtime"] == mtime:
        return ROUTES_CACHE
    lines = ROUTES.read_text().splitlines()
    sections = []
    current = None
    index = 0
    while index < len(lines):
        line = lines[index]
        if line.startswith("## "):
            heading = line[3:].strip()
            scope = PATH_CELL_RE.search(heading)
            current = {
                "heading": re.sub(r"\s*\(.*\)\s*$", "", heading),
                "raw_heading": heading,
                "line": index + 1,
                "scope": scope.group(1) if scope else None,
                "columns": [],
                "rows": [],
                "prose": [],
            }
            sections.append(current)
            index += 1
            continue
        if (
            current is not None
            and line.startswith("|")
            and index + 1 < len(lines)
            and DELIMITER_RE.match(lines[index + 1].strip())
        ):
            headers = split_row(line)
            current["columns"] = headers
            index += 2
            while index < len(lines) and lines[index].startswith("|"):
                current["rows"].append(
                    {"line": index + 1, "cells": split_row(lines[index]), "columns": headers}
                )
                index += 1
            continue
        if current is not None and line.strip() and not line.startswith("#"):
            current["prose"].append(line.strip())
        index += 1

    rows = []
    for section in sections:
        for raw in section["rows"]:
            record = build_record(section, raw)
            if record is not None:
                rows.append(record)
    ROUTES_CACHE.update(
        {"mtime": mtime, "sections": sections, "rows": rows, "idf": build_idf(rows)}
    )
    return ROUTES_CACHE


def build_record(section, raw):
    columns = raw["columns"]
    cells = raw["cells"]
    named = {}
    surplus = []
    for position, cell in enumerate(cells):
        if position < len(columns):
            named[columns[position]] = cell
        elif cell:
            surplus.append(cell)
    concern = next(
        (named[key] for key in ("Task / Concern", "Task", "Concern") if named.get(key)), None
    )
    file_cell = named.get("File")
    steps = [named[key] for key in columns if key.startswith("Step") and named.get(key)]
    if concern is None and named.get("Purpose"):
        concern = named["Purpose"]
    if concern is None:
        return None
    notes = [named[key] for key in ("Notes", "Active Hosts", "What") if named.get(key)] + surplus
    paths = extract_paths(file_cell or "")
    for step in steps:
        paths.extend(extract_paths(step))
    if not paths:
        return None
    text = " ".join([concern] + notes + [file_cell or ""] + steps)
    return {
        "section": section["heading"],
        "section_scope": section["scope"],
        "line": raw["line"],
        "concern": concern,
        "paths": paths,
        "steps": steps,
        "notes": "; ".join(notes),
        "hosts": section_hosts(section["heading"], text),
        "tokens": tokenize(concern),
        "note_tokens": tokenize("; ".join(notes)),
        "path_tokens": tokenize(" ".join(entry["path"] for entry in paths)),
    }


def variants(word):
    forms = {word}
    if len(word) > 3 and word.endswith("es"):
        forms.add(word[:-2])
    if len(word) > 3 and word.endswith("s"):
        forms.add(word[:-1])
    return forms


def tokenize(text):
    tokens = set()
    for word in re.split(r"[^a-z0-9]+", (text or "").lower()):
        if len(word) > 2 and word not in STOP_WORDS:
            tokens |= variants(word)
    return tokens


def build_idf(rows):
    import math

    total = max(1, len(rows))
    counts = {}
    for row in rows:
        for token in row["tokens"] | row["note_tokens"] | row["path_tokens"]:
            counts[token] = counts.get(token, 0) + 1
    return {token: math.log(1 + total / (1 + count)) for token, count in counts.items()}


def score_row(row, query_tokens, raw_query, idf):
    weight = lambda tokens, factor: factor * sum(idf.get(token, 1.0) for token in query_tokens & tokens)
    score = weight(row["tokens"], 1.0) + weight(row["note_tokens"], 0.4) + weight(row["path_tokens"], 0.6)
    if raw_query and raw_query in row["concern"].lower():
        score += 2.0
    for entry in row["paths"]:
        if Path(entry["path"]).stem.lower() in query_tokens:
            score += 1.0
            break
    if row["section"].startswith("Optional"):
        score -= 1.5
    return score


def tool_route(args, request_id, token):
    query = (args.get("query") or "").strip()
    if not query:
        raise ToolError("query is required")
    host = args.get("host")
    if host is not None and host not in HOSTS:
        raise ToolError(f"unknown host {host!r}; expected one of {', '.join(HOSTS)}")
    limit = max(1, min(int(args.get("limit") or 5), 25))
    cache = parse_routes()
    query_tokens = tokenize(query)
    scored = []
    for row in cache["rows"]:
        if host is not None and host not in row["hosts"]:
            continue
        score = score_row(row, query_tokens, query.lower(), cache["idf"])
        if score > 0:
            scored.append((score, row))
    scored.sort(key=lambda pair: (-pair[0], pair[1]["line"]))
    matches = []
    for score, row in scored[:limit]:
        match = {
            "score": round(score, 2),
            "section": row["section"],
            "section_scope": row["section_scope"],
            "routes_line": row["line"],
            "concern": row["concern"],
            "paths": row["paths"],
            "hosts": row["hosts"],
        }
        if row["notes"]:
            match["notes"] = row["notes"]
        if row["steps"]:
            match["steps"] = row["steps"]
        matches.append(match)
    header = {
        "query": query,
        "source": "docs/routes.md",
        "confident": bool(matches) and matches[0]["score"] >= 1.0,
        "matches": matches,
    }
    if not header["confident"]:
        header["fallback"] = (
            "not routed: search with glob/grep, then add the row to docs/routes.md "
            "per the nix-routing skill"
        )
    return envelope(header), False


def tool_route_file(args, request_id, token):
    target = (args.get("path") or "").strip()
    if target.startswith("./"):
        target = target[2:]
    if not target:
        raise ToolError("path is required")
    cache = parse_routes()
    entries = []
    loose = []
    for row in cache["rows"]:
        for entry in row["paths"]:
            candidate = entry["path"]
            record = {
                "section": row["section"],
                "routes_line": row["line"],
                "concern": row["concern"],
                "matched_path": candidate,
                "notes": row["notes"],
                "hosts": row["hosts"],
            }
            if candidate == target or (entry.get("glob") and fnmatch.fnmatch(target, candidate)):
                entries.append(record)
                break
            if Path(candidate).name == Path(target).name:
                record["match"] = "basename only"
                loose.append(record)
                break
    header = {
        "path": target,
        "exists": (REPO / target).exists(),
        "routed": bool(entries),
        "entries": entries,
    }
    if not entries:
        header["suggested_section"] = suggest_section(target)
        header["action"] = "add a row to docs/routes.md per the nix-routing skill"
        if loose:
            header["same_basename_elsewhere"] = loose[:10]
    return envelope(header), False


def suggest_section(target):
    if target.startswith("home-manager/modules/"):
        return "Home Manager Modules"
    if target.startswith("hosts/"):
        return "PC-Specific Modules"
    if target.startswith("pkgs/"):
        return "Cross-Cutting Tasks"
    if target.startswith("modules/"):
        return "System Modules"
    return "Other Files"


def repo_nix_files():
    found = set()
    for base in ("modules", "hosts", "home-manager", "pkgs"):
        root = REPO / base
        if root.exists():
            found.update(
                str(path.relative_to(REPO)) for path in root.rglob("*.nix")
            )
    found.update(str(path.relative_to(REPO)) for path in REPO.glob("*.nix"))
    return found


def tool_routes_audit(args, request_id, token):
    cache = parse_routes()
    wanted = args.get("section")
    sections = []
    for section in cache["sections"]:
        summary = {
            "heading": section["heading"],
            "line": section["line"],
            "scope": section["scope"],
            "columns": section["columns"],
            "rows": len(section["rows"]),
        }
        if section["prose"]:
            summary["prose"] = " ".join(section["prose"])
        sections.append(summary)
    header = {"file": "docs/routes.md", "sections": sections}
    if wanted:
        picked = [
            row
            for row in cache["rows"]
            if row["section"].lower().startswith(wanted.lower())
        ]
        if not picked:
            raise ToolError(
                f"no section matching {wanted!r}; headings: "
                + ", ".join(item["heading"] for item in sections)
            )
        header["section"] = wanted
        header["rows"] = [
            {
                "routes_line": row["line"],
                "concern": row["concern"],
                "paths": row["paths"],
                "notes": row["notes"],
                "hosts": row["hosts"],
            }
            for row in picked
        ]
    if args.get("validate", True):
        dead = []
        routed = set()
        for row in cache["rows"]:
            for entry in row["paths"]:
                routed.add(entry["path"])
                if entry["exists"] is False and not entry.get("bare_name"):
                    dead.append(
                        {
                            "routes_line": row["line"],
                            "section": row["section"],
                            "concern": row["concern"],
                            "path": entry["path"],
                        }
                    )
        globs = [entry for entry in routed if "*" in entry]
        unrouted = sorted(
            path
            for path in repo_nix_files()
            if path not in routed
            and not any(fnmatch.fnmatch(path, pattern) for pattern in globs)
        )
        header["dead_paths"] = dead
        header["unrouted_nix_files"] = unrouted
    return envelope(header), False


TOOLS = [
    {
        "name": "rebuild",
        "title": "nixos-rebuild",
        "description": (
            "Run nixos-rebuild for this flake (switch|boot|test|dry-activate|build). "
            "Mirrors the Makefile invocation (--impure --cores nproc). Runs detached, so it "
            "survives an MCP restart; returns the job id, exit code, first error and a log tail. "
            "Refuses when untracked .nix files exist, and refuses to activate another host."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["switch", "boot", "test", "dry-activate", "build"],
                    "description": "switch = make switch; boot adds --install-bootloader; build needs no root",
                },
                "host": {"type": "string", "enum": list(HOSTS), "description": "defaults to this machine"},
                "wait_s": {"type": "integer", "description": "seconds to wait before returning the job id (default 1800)"},
                "allow_untracked": {"type": "boolean", "description": "proceed despite untracked .nix files"},
            },
            "required": ["action"],
        },
        "annotations": {"readOnlyHint": False, "destructiveHint": True, "idempotentHint": False, "openWorldHint": False},
        "handler": tool_rebuild,
    },
    {
        "name": "rebuild_log",
        "title": "Rebuild job log",
        "description": "Tail the log of a rebuild/rollback/flake-update job started by this server. Omit job for the most recent one.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "job": {"type": "string", "description": "job id from rebuild"},
                "lines": {"type": "integer", "description": "log lines to return (default 80)"},
                "grep": {"type": "string", "description": "keep only lines matching this regex"},
            },
        },
        "annotations": {"readOnlyHint": True, "openWorldHint": False},
        "handler": tool_rebuild_log,
    },
    {
        "name": "dry_run",
        "title": "Verification gate",
        "description": (
            "The documented pre-switch gate: nix build .#nixosConfigurations.<host>."
            "config.system.build.toplevel --dry-run. Passes only on exit 0 with no evaluation "
            "or deprecation warnings; the 'Git tree is dirty' warning is excluded."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {"host": {"type": "string", "enum": list(HOSTS), "description": "defaults to this machine"}},
        },
        "annotations": {"readOnlyHint": True, "openWorldHint": False},
        "handler": tool_dry_run,
    },
    {
        "name": "eval",
        "title": "Evaluate nix",
        "description": (
            "Short-hand `nix eval` against this flake. `attr` is a path under the host's "
            "config, so `security.sudo.extraRules` expands to "
            "`.#nixosConfigurations.<host>.config.security.sudo.extraRules`; prefixes `hm.` "
            "(home-manager user config) and `options.` are understood, and any string "
            "containing `#` is used as a literal flake attr. `expr` instead evaluates a Nix "
            "expression with these bindings already in scope: flake, hosts, configs, config, "
            "options, pkgs, lib, hm - so no `builtins.getFlake` boilerplate. Returns parsed "
            "JSON by default, falls back to nix's own printer for values JSON cannot hold; "
            "raw=true gives `--raw` for strings. On a missing attribute it lists the "
            "available names of the parent."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "attr": {"type": "string", "description": "option path, hm.<path>, options.<path>, or a literal flake attr with #"},
                "expr": {"type": "string", "description": "nix expression; flake/hosts/configs/config/options/pkgs/lib/hm are pre-bound"},
                "apply": {"type": "string", "description": "nix function applied to the value, e.g. builtins.attrNames (attr mode only)"},
                "raw": {"type": "boolean", "description": "use --raw instead of --json (strings and paths)"},
                "host": {"type": "string", "enum": list(HOSTS), "description": "defaults to this machine"},
            },
        },
        "annotations": {"readOnlyHint": True, "openWorldHint": False},
        "handler": tool_eval,
    },
    {
        "name": "generations",
        "title": "System generations",
        "description": "List NixOS system generations with build date, nixos version and kernel.",
        "inputSchema": {
            "type": "object",
            "properties": {"limit": {"type": "integer", "description": "newest N generations (default 10)"}},
        },
        "annotations": {"readOnlyHint": True, "openWorldHint": False},
        "handler": tool_generations,
    },
    {
        "name": "rollback",
        "title": "Roll back one generation",
        "description": "Activate the previous system generation via nixos-rebuild switch --rollback. Requires confirm=\"yes\".",
        "inputSchema": {
            "type": "object",
            "properties": {"confirm": {"type": "string", "description": "must be \"yes\""}},
            "required": ["confirm"],
        },
        "annotations": {"readOnlyHint": False, "destructiveHint": True, "idempotentHint": False, "openWorldHint": False},
        "handler": tool_rollback,
    },
    {
        "name": "diff_generations",
        "title": "Diff two generations",
        "description": "nix store diff-closures between two system generations. Defaults to the previous generation vs the current one.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "from": {"type": "integer", "description": "older generation number"},
                "to": {"type": "integer", "description": "newer generation number (default: current)"},
            },
        },
        "annotations": {"readOnlyHint": True, "openWorldHint": False},
        "handler": tool_diff_generations,
    },
    {
        "name": "gc",
        "title": "Collect garbage",
        "description": (
            "sudo nix-collect-garbage: delete old generations of every profile, then sweep "
            "unreachable store paths. mode=full is `-d` (all non-current generations); "
            "mode=older_than is `--delete-older-than <days>d`. The current generation is always "
            "kept, but rollbacks to the deleted ones become impossible, so it needs "
            "confirm=\"yes\". dry_run=true previews and deletes nothing."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "mode": {
                    "type": "string",
                    "enum": ["full", "older_than"],
                    "description": "full = -d (default); older_than needs days",
                },
                "days": {"type": "integer", "description": "keep generations newer than this many days"},
                "confirm": {"type": "string", "description": "must be \"yes\" unless dry_run is set"},
                "dry_run": {"type": "boolean", "description": "report what would be deleted, delete nothing"},
                "wait_s": {"type": "integer", "description": "seconds to wait before returning the job id (default 1800)"},
            },
        },
        "annotations": {"readOnlyHint": False, "destructiveHint": True, "idempotentHint": False, "openWorldHint": False},
        "handler": tool_gc,
    },
    {
        "name": "flake_update",
        "title": "Update flake inputs",
        "description": (
            "nix flake update for all or selected inputs, then report which locked revisions moved. "
            "Rewrites flake.lock, so it requires confirm=\"yes\". Verify with dry_run afterwards."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "inputs": {"type": "array", "items": {"type": "string"}, "description": "input names; empty = every input"},
                "confirm": {"type": "string", "description": "must be \"yes\""},
                "wait_s": {"type": "integer", "description": "seconds to wait before returning the job id (default 900)"},
            },
            "required": ["confirm"],
        },
        "annotations": {"readOnlyHint": False, "destructiveHint": True, "idempotentHint": False, "openWorldHint": True},
        "handler": tool_flake_update,
    },
    {
        "name": "flake_age",
        "title": "Flake input age",
        "description": (
            "How stale a root flake input is. Resolves .nodes[.root].inputs.<name> in flake.lock, "
            "never the same-named transitive copy, and reports rev, date, age in days and the "
            "repo commit that bumped it."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "input": {"type": "string", "description": "root input name (default nixpkgs)"},
                "with_commit": {"type": "boolean", "description": "also find the bump commit (default true)"},
            },
        },
        "annotations": {"readOnlyHint": True, "openWorldHint": False},
        "handler": tool_flake_age,
    },
    {
        "name": "health",
        "title": "Unit health",
        "description": "Failed system and user units, plus the journal for one unit. Use after a switch to verify activation.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "unit": {"type": "string", "description": "unit name to fetch the journal for"},
                "lines": {"type": "integer", "description": "journal lines (default 60)"},
            },
        },
        "annotations": {"readOnlyHint": True, "openWorldHint": False},
        "handler": tool_health,
    },
    {
        "name": "route",
        "title": "Route a config task to a file",
        "description": (
            "Resolve a natural-language config task to the exact file(s) to edit, from "
            "docs/routes.md. Use this INSTEAD of glob/grep when locating a NixOS or Home Manager "
            "module. Returns ranked rows with section, host scope, notes and path existence."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "task in plain language, e.g. 'enable bluetooth on the laptop'"},
                "host": {"type": "string", "enum": list(HOSTS), "description": "restrict to rows applicable to this host"},
                "limit": {"type": "integer", "description": "max matches (default 5)"},
            },
            "required": ["query"],
        },
        "annotations": {"readOnlyHint": True, "openWorldHint": False},
        "handler": tool_route,
    },
    {
        "name": "route_file",
        "title": "Reverse route lookup",
        "description": "What a file owns according to docs/routes.md: matching concerns, sections and host scope. Use before editing a file, or to check whether a new module still needs a row.",
        "inputSchema": {
            "type": "object",
            "properties": {"path": {"type": "string", "description": "repo-relative path, e.g. modules/grafana.nix"}},
            "required": ["path"],
        },
        "annotations": {"readOnlyHint": True, "openWorldHint": False},
        "handler": tool_route_file,
    },
    {
        "name": "routes_audit",
        "title": "Routing table audit",
        "description": "Section map of docs/routes.md, plus rows of one section, dead path references and .nix files that have no row.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "section": {"type": "string", "description": "dump the rows of one section (prefix match on the heading)"},
                "validate": {"type": "boolean", "description": "report dead and unrouted paths (default true)"},
            },
        },
        "annotations": {"readOnlyHint": True, "openWorldHint": False},
        "handler": tool_routes_audit,
    },
]

TOOL_INDEX = {tool["name"]: tool for tool in TOOLS}
PUBLIC_TOOLS = [{key: tool[key] for key in tool if key != "handler"} for tool in TOOLS]


def call_tool(params, request_id):
    if not isinstance(params, dict):
        fail(request_id, -32602, "params must be an object")
        return
    name = params.get("name")
    tool = TOOL_INDEX.get(name)
    if tool is None:
        fail(request_id, -32602, f"Unknown tool: {name}")
        return
    arguments = params.get("arguments") or {}
    if not isinstance(arguments, dict):
        fail(request_id, -32602, "arguments must be an object")
        return
    missing = [
        key for key in tool["inputSchema"].get("required", []) if arguments.get(key) in (None, "")
    ]
    if missing:
        fail(request_id, -32602, f"Missing required argument(s): {', '.join(missing)}")
        return
    meta = params.get("_meta")
    token = meta.get("progressToken") if isinstance(meta, dict) else None
    try:
        text, is_error = tool["handler"](arguments, request_id, token)
    except ToolError as error:
        text, is_error = str(error), True
    if str(request_id) in CANCELLED:
        return
    result = {"content": [{"type": "text", "text": text}]}
    if is_error:
        result["isError"] = True
    reply(request_id, result)


def handle(message):
    request_id = message.get("id")
    try:
        dispatch(message, request_id)
    except Exception as error:
        if request_id is not None:
            fail(request_id, -32603, f"{type(error).__name__}: {error}")
    finally:
        if request_id is not None:
            CANCELLED.discard(str(request_id))


def dispatch(message, request_id):
    method = message.get("method")
    params = message.get("params")
    if not isinstance(params, dict):
        params = {}
    if request_id is None:
        if method == "notifications/cancelled":
            cancelled = params.get("requestId")
            if cancelled is not None:
                CANCELLED.add(str(cancelled))
        return
    if method == "initialize":
        requested = params.get("protocolVersion")
        reply(
            request_id,
            {
                "protocolVersion": requested if requested in PROTOCOLS else LATEST_PROTOCOL,
                "capabilities": {"tools": {"listChanged": False}},
                "serverInfo": SERVER_INFO,
                "instructions": INSTRUCTIONS,
            },
        )
        return
    if method == "ping":
        reply(request_id, {})
        return
    if method == "tools/list":
        reply(request_id, {"tools": PUBLIC_TOOLS})
        return
    if method == "tools/call":
        call_tool(params, request_id)
        return
    fail(request_id, -32601, f"Method not found: {method}")


def main():
    job_dir()
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            message = json.loads(line)
        except ValueError:
            continue
        if not isinstance(message, dict):
            continue
        if message.get("method") == "initialize":
            handle(message)
            continue
        threading.Thread(target=handle, args=(message,), daemon=False).start()


if __name__ == "__main__":
    main()
