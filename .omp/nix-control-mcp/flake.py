import json
import time

from config import LOCK, MISSING_ATTR_RE, OWNER, REPO
from jobs import await_job, finish_job, read_log, start_job
from protocol import ToolError
from shell import first_error, nix_noise, require_host, run, run_split
from text import clamp, envelope, tail


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
    header["next"] = "rebuild action=switch"
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
