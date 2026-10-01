#!/usr/bin/env python3
from __future__ import annotations

import fcntl
import json
import os
import re
import urllib.error
import urllib.parse
import urllib.request
import time
from pathlib import Path

PROFILE = os.environ.get("FDS_PROFILE", "deepseek-web")
PROXY = os.environ.get("FDS_PROXY", "http://127.0.0.1:9655").rstrip("/")
KEY_PREFIX = os.environ.get("FDS_KEY_PREFIX", "jcode")
FALLBACK_KEY = os.environ.get("FDS_FALLBACK_KEY", "jcode")
ENV_FILE_NAME = os.environ.get("FDS_ENV_FILE", "deepseek-web.env")

ENV_KEY = "JCODE_OPENAI_EXTRA_BODY"
STATE_FILE_NAME = "deepseek-session.state"
LOG_FILE_NAME = "deepseek-session.log"
LOCK_FILE_NAME = "deepseek-session.lock"
LOG_LIMIT_BYTES = 64 * 1024
LOCK_WAIT_SECONDS = 20
PENDING_LIMIT = 8
HTTP_TIMEOUT = 5

ASSIGNMENT = re.compile(r"^\s*(?:export\s+)?" + re.escape(ENV_KEY) + r"\s*=")


def config_dir() -> Path:
    base = os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")
    return Path(base) / "jcode"


def agent_key(session_id: str) -> str:
    return f"{KEY_PREFIX}-{session_id}"


def env_session_value(env_file: Path) -> str:
    try:
        lines = env_file.read_text().splitlines()
    except OSError:
        return ""
    for line in lines:
        if not ASSIGNMENT.match(line):
            continue
        raw = line.split("=", 1)[1].strip()
        try:
            parsed = json.loads(raw)
        except ValueError:
            continue
        if isinstance(parsed, dict) and isinstance(parsed.get("session"), str):
            return parsed["session"]
    return ""


def write_env_file(env_file: Path, key: str) -> None:
    try:
        kept = [
            line for line in env_file.read_text().splitlines() if not ASSIGNMENT.match(line)
        ]
    except OSError:
        kept = []
    kept.append(f"{ENV_KEY}={json.dumps({'session': key}, separators=(',', ':'))}")
    tmp = env_file.with_name(f"{env_file.name}.tmp{os.getpid()}")
    tmp.write_text("\n".join(kept) + "\n")
    tmp.chmod(0o600)
    tmp.replace(env_file)


def read_state(state_file: Path) -> tuple[str, str, list[str]]:
    try:
        lines = [line for line in state_file.read_text().splitlines() if line]
    except OSError:
        return "", "", []
    session = lines[0] if lines else ""
    in_use = lines[1] if len(lines) > 1 else ""
    return session, in_use, lines[2:]


def write_state(state_file: Path, session: str, in_use: str, pending: list[str]) -> None:
    tmp = state_file.with_name(f"{state_file.name}.tmp{os.getpid()}")
    tmp.write_text("\n".join([session, in_use, *pending]) + "\n")
    tmp.chmod(0o600)
    tmp.replace(state_file)


def live_sessions() -> set[str] | None:
    try:
        with urllib.request.urlopen(f"{PROXY}/v1/sessions", timeout=HTTP_TIMEOUT) as response:
            payload = json.load(response)
    except (OSError, ValueError, urllib.error.URLError):
        return None
    agents = payload.get("agents")
    if not isinstance(agents, list):
        return None
    return {
        entry.get("agent", "")
        for entry in agents
        if isinstance(entry, dict) and entry.get("session_id")
    }


def reset_session(name: str) -> bool:
    request = urllib.request.Request(
        f"{PROXY}/reset-session?agent={urllib.parse.quote(name)}", method="POST"
    )
    try:
        with urllib.request.urlopen(request, timeout=HTTP_TIMEOUT):
            return True
    except (OSError, urllib.error.URLError):
        return False


def append_log(log_file: Path, message: str) -> None:
    try:
        with log_file.open("a") as handle:
            handle.write(message + "\n")
        if log_file.stat().st_size > LOG_LIMIT_BYTES:
            data = log_file.read_bytes()[-LOG_LIMIT_BYTES // 2 :]
            cut = data.find(b"\n")
            tmp = log_file.with_name(f"{log_file.name}.tmp{os.getpid()}")
            tmp.write_bytes(data[cut + 1 :] if cut >= 0 else data)
            tmp.chmod(0o600)
            tmp.replace(log_file)
    except OSError:
        pass


def sweep(pending: list[str], keep: set[str]) -> tuple[list[str], list[str]]:
    live = live_sessions()
    if live is None:
        return [], pending
    cleared: list[str] = []
    remaining: list[str] = []
    for name in pending:
        if name in keep or name not in live:
            remaining.append(name)
        elif reset_session(name):
            cleared.append(name)
        else:
            remaining.append(name)
    return cleared, remaining


def main() -> int:
    active = os.environ.get("JCODE_NAMED_PROVIDER_PROFILE") or os.environ.get(
        "JCODE_PROVIDER_PROFILE_NAME"
    )
    if active != PROFILE:
        return 0

    session_id = os.environ.get("JCODE_HOOK_SESSION_ID", "")
    if not session_id:
        return 0

    event = os.environ.get("JCODE_HOOK_EVENT", "")
    source = os.environ.get("JCODE_HOOK_SOURCE", "")
    home = config_dir()
    env_file = home / ENV_FILE_NAME
    state_file = home / STATE_FILE_NAME
    log_file = home / LOG_FILE_NAME
    key = agent_key(session_id)

    try:
        home.mkdir(parents=True, exist_ok=True)
    except OSError:
        return 0

    lock_file = home / LOCK_FILE_NAME
    try:
        with lock_file.open("a+") as lock:
            deadline = LOCK_WAIT_SECONDS
            while True:
                try:
                    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    break
                except OSError:
                    if deadline <= 0:
                        return 0
                    deadline -= 1
                    time.sleep(1)
            return transition(home, env_file, state_file, log_file, session_id, key, event, source)
    except OSError:
        return 0


def transition(
    home: Path,
    env_file: Path,
    state_file: Path,
    log_file: Path,
    session_id: str,
    key: str,
    event: str,
    source: str,
) -> int:
    in_use = env_session_value(env_file) or FALLBACK_KEY
    previous_session, previous_in_use, pending = read_state(state_file)
    if session_id == previous_session and in_use == key and not pending:
        return 0

    if previous_session and previous_session != session_id and previous_in_use:
        pending = [previous_in_use, *pending]
    pending = [
        name for name in dict.fromkeys(pending) if name and name not in (key, in_use)
    ][:PENDING_LIMIT]

    cleared, remaining = sweep(pending, keep={key, in_use})

    try:
        write_env_file(env_file, key)
        write_state(state_file, session_id, in_use, remaining)
    except OSError as error:
        append_log(
            log_file,
            f"write-failed event={event or 'hook'} key={key} error={error.__class__.__name__}",
        )
        return 1

    append_log(
        log_file,
        f"{event or 'hook'} source={source or '-'} key={key} in_use={in_use} "
        f"previous={previous_session or '-'} cleared={','.join(cleared) or '-'} "
        f"pending={','.join(remaining) or '-'}",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
