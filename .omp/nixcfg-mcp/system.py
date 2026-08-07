import json
import re

from config import (
    BUILT_RE,
    DIRTY_WARNING_RE,
    FETCH_RE,
    FREED_RE,
    NIX_COLLECT_GARBAGE,
    NIXOS_REBUILD,
    SYSTEM_PROFILES,
    WOULD_DELETE_RE,
)
from jobs import await_job, finish_job, known_jobs, read_log, refresh_job, start_job
from protocol import ToolError
from shell import (
    cores,
    current_host,
    failed_derivation,
    first_error,
    require_host,
    run,
    untracked_nix,
)
from text import envelope, tail


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
