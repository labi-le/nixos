#!/usr/bin/env python3
import json
import os
import re
import subprocess
import sys

PROTECTED = re.compile(r"^(?:master|main|develop|trunk|RELEASE-.*|release/.*|releases/.*)$")
SEPARATORS = re.compile(r"(?:\|\||&&|[;\n|])")
SWITCHES = re.compile(r"^(?:checkout|switch)$")
OPAQUE_SWITCH = re.compile(r"^(?:--|--detach|-d|-p|--patch|--orphan|--merge|-m)$")
NO_WRITE = re.compile(r"^(?:--dry-run|-n|--help)$")
TAKES_VALUE = re.compile(r"^(?:-o|--push-option|--receive-pack|--exec|--repo)$")
HOW = "Point the branch at its own remote branch, then push:\n  git branch --unset-upstream\n  git push -u origin <branch>"


def fail(reason):
    sys.stderr.write("Blocked: " + reason.strip() + "\n")
    sys.exit(2)


def allow():
    sys.exit(0)


def split_commands(text):
    segments = []
    token = ""
    quote = None
    escaped = False
    at = 0
    while at < len(text):
        ch = text[at]
        if escaped:
            token += ch
            escaped = False
            at += 1
            continue
        if ch == "\\" and quote != "'":
            token += ch
            escaped = True
            at += 1
            continue
        if quote:
            token += ch
            if ch == quote:
                quote = None
            at += 1
            continue
        if ch in ("'", '"'):
            quote = ch
            token += ch
            at += 1
            continue
        two = text[at : at + 2]
        if two in ("&&", "||"):
            segments.append(token)
            token = ""
            at += 2
            continue
        if ch in (";", "|", "\n"):
            segments.append(token)
            token = ""
            at += 1
            continue
        token += ch
        at += 1
    segments.append(token)
    return segments

def resolve(base, directory):
    if directory.startswith("/") or directory.startswith("~"):
        return directory
    return base.rstrip("/") + "/" + directory


def switched_to(argv, at):
    for i in range(at + 1, len(argv)):
        arg = argv[i]
        if OPAQUE_SWITCH.match(arg):
            return None
        if arg.startswith("-"):
            continue
        return arg
    return None


def push_invocations(command, base):
    found = []
    cwd = base
    local = None
    for segment in split_commands(command):
        argv = [word for word in segment.strip().split() if word]
        if not argv:
            continue
        if argv[0] == "cd" and len(argv) > 1 and not argv[1].startswith("-"):
            cwd = resolve(cwd, argv[1])
            local = None
            continue
        git = next((i for i, word in enumerate(argv) if word == "git" or word.endswith("/git")), -1)
        if git == -1:
            continue
        at = git + 1
        chdir = None
        while at < len(argv) and argv[at].startswith("-"):
            if argv[at] == "-C" and at + 1 < len(argv):
                chdir = argv[at + 1]
            at += 2 if argv[at] in ("-C", "-c") else 1
        sub = argv[at] if at < len(argv) else None
        if sub and SWITCHES.match(sub) and not chdir:
            local = switched_to(argv, at)
            continue
        if sub != "push":
            continue
        found.append(
            {
                "args": argv[at + 1 :],
                "cwd": resolve(cwd, chdir) if chdir else cwd,
                "local": None if chdir else local,
            }
        )
    return found


def refspec_target(args):
    positional = []
    at = 0
    while at < len(args):
        arg = args[at]
        if NO_WRITE.match(arg):
            return None
        if TAKES_VALUE.match(arg):
            at += 2
            continue
        if arg.startswith("-"):
            at += 1
            continue
        positional.append(arg)
        at += 1
    if len(positional) < 2:
        return False
    refspec = positional[1]
    colon = refspec.rfind(":")
    dst = refspec if colon == -1 else refspec[colon + 1 :]
    dst = dst.lstrip("+")
    if dst.startswith("refs/heads/"):
        dst = dst[len("refs/heads/") :]
    return dst or False


def probe_in(cwd):
    def probe(args):
        try:
            out = subprocess.run(
                ["git", *args],
                cwd=cwd,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                timeout=2,
                check=False,
            )
        except Exception:
            return None
        if out.returncode != 0:
            return None
        text = out.stdout.decode("utf-8", "replace").strip()
        return text or None

    return probe


def resolve_target(args, probe, known=None):
    local = known or probe(["symbolic-ref", "--short", "-q", "HEAD"])
    spec = refspec_target(args)
    if spec is None:
        return None
    if spec is not False:
        return {"local": local, "remote": spec, "via": "refspec"}
    if not local:
        return {"local": local, "remote": None, "via": None}
    for suffix, via in (("@{push}", "push"), ("@{upstream}", "upstream")):
        resolved = probe(["rev-parse", "--abbrev-ref", "--symbolic-full-name", local + suffix])
        if not resolved:
            continue
        slash = resolved.find("/")
        return {"local": local, "remote": resolved if slash == -1 else resolved[slash + 1 :], "via": via}
    return {"local": local, "remote": None, "via": None}


def push_violation(target):
    local = target["local"]
    remote = target["remote"]
    via = target["via"]
    if not remote or not local or remote == local:
        return None
    if PROTECTED.match(local):
        return None
    source = {
        "refspec": "the refspec you passed",
        "push": "this branch's push target (branch.<name>.pushRemote / push.default)",
        "upstream": "this branch's upstream",
    }.get(via, "the repository state")
    danger = (
        "That is a protected branch, so the push would land "
        f"{local} straight in {remote}."
        if PROTECTED.match(remote)
        else "Local branch and remote branch disagree, so the push would update the wrong branch."
    )
    return f"local branch `{local}` would push to `{remote}` ({source}).\n{danger}\n\n{HOW}"


def main():
    try:
        raw = sys.stdin.read()
    except Exception:
        allow()
    try:
        payload = json.loads(raw) if raw.strip() else {}
    except Exception:
        allow()
    if not isinstance(payload, dict):
        allow()
    tool = os.environ.get("JCODE_HOOK_TOOL_NAME", "").strip().lower()
    if tool not in ("bash", "execute", "run", "shell"):
        allow()
    command = payload.get("command")
    if not isinstance(command, str) or "git" not in command:
        allow()
    cwd = payload.get("cwd")
    if not isinstance(cwd, str) or not cwd:
        cwd = os.environ.get("JCODE_HOOK_CWD") or os.getcwd()

    try:
        for invocation in push_invocations(command, cwd):
            target = resolve_target(invocation["args"], probe_in(invocation["cwd"]), invocation["local"])
            if target is None:
                continue
            violation = push_violation(target)
            if violation:
                fail(violation)
    except SystemExit:
        raise
    except Exception:
        allow()
    allow()


if __name__ == "__main__":
    main()
