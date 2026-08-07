import os
import subprocess

from config import DIRTY_WARNING_RE, DRV_FAIL_RE, HOSTS, REPO, SHORT_TIMEOUT
from protocol import ToolError


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


def run_split(argv, timeout=SHORT_TIMEOUT, cwd=None, stdin_data=None, env_extra=None, raw=False):
    child_env = None
    if env_extra:
        child_env = dict(os.environ)
        child_env.update(env_extra)
    try:
        done = subprocess.run(
            argv,
            cwd=str(cwd or REPO),
            input=stdin_data if stdin_data is not None else None,
            stdin=subprocess.DEVNULL if stdin_data is None else None,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=child_env,
            timeout=timeout,
        )
    except FileNotFoundError:
        raise ToolError(f"executable not found: {argv[0]}")
    except subprocess.TimeoutExpired:
        raise ToolError(f"timed out after {timeout}s: {' '.join(argv)}")
    return (
        done.returncode,
        done.stdout if raw else done.stdout.decode("utf-8", "replace"),
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
