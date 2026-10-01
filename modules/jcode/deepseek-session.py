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

PROXY = os.environ.get("FDS_PROXY", "http://127.0.0.1:9655").rstrip("/")
AGENT_KEY = os.environ.get("FDS_AGENT_KEY", "jcode")
ENV_FILE_NAME = os.environ.get("FDS_ENV_FILE", "deepseek-web.env")

ENV_KEY = "JCODE_OPENAI_EXTRA_BODY"
STATE_FILE_NAME = "deepseek-session.state"
LOG_FILE_NAME = "deepseek-session.log"
LOCK_FILE_NAME = "deepseek-session.lock"
LOG_LIMIT_BYTES = 64 * 1024
LOCK_WAIT_SECONDS = 20
HTTP_TIMEOUT = 5

ASSIGNMENT = re.compile(r"^\s*(?:export\s+)?" + re.escape(ENV_KEY) + r"\s*=")


def config_dir() -> Path:
    base = os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")
    return Path(base) / "jcode"


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


def write_env_file(env_file: Path) -> None:
    try:
        kept = [
            line for line in env_file.read_text().splitlines() if not ASSIGNMENT.match(line)
        ]
    except OSError:
        kept = []
    kept.append(f"{ENV_KEY}={json.dumps({'session': AGENT_KEY}, separators=(',', ':'))}")
    tmp = env_file.with_name(f"{env_file.name}.tmp{os.getpid()}")
    tmp.write_text("\n".join(kept) + "\n")
    tmp.chmod(0o600)
    tmp.replace(env_file)


def read_owner(state_file: Path) -> str:
    try:
        lines = [line for line in state_file.read_text().splitlines() if line]
    except OSError:
        return ""
    return lines[0] if lines else ""


def write_owner(state_file: Path, session_id: str) -> None:
    tmp = state_file.with_name(f"{state_file.name}.tmp{os.getpid()}")
    tmp.write_text(session_id + "\n")
    tmp.chmod(0o600)
    tmp.replace(state_file)


def start_new_chat() -> str:
    request = urllib.request.Request(
        f"{PROXY}/reset-session?agent={urllib.parse.quote(AGENT_KEY)}", method="POST"
    )
    try:
        with urllib.request.urlopen(request, timeout=HTTP_TIMEOUT) as response:
            json.load(response)
        return "new-chat"
    except urllib.error.HTTPError as error:
        return "no-chat" if error.code == 404 else "reset-failed"
    except (OSError, ValueError, urllib.error.URLError):
        return "unreachable"


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


def main() -> int:
    session_id = os.environ.get("JCODE_HOOK_SESSION_ID", "")
    if not session_id:
        return 0

    event = os.environ.get("JCODE_HOOK_EVENT", "")
    source = os.environ.get("JCODE_HOOK_SOURCE", "")
    home = config_dir()
    env_file = home / ENV_FILE_NAME
    state_file = home / STATE_FILE_NAME
    log_file = home / LOG_FILE_NAME

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
            return transition(
                env_file, state_file, log_file, session_id, event, source
            )
    except OSError:
        return 0


def transition(
    env_file: Path,
    state_file: Path,
    log_file: Path,
    session_id: str,
    event: str,
    source: str,
) -> int:
    if env_session_value(env_file) != AGENT_KEY:
        try:
            write_env_file(env_file)
        except OSError as error:
            append_log(
                log_file,
                f"write-failed event={event or 'hook'} error={error.__class__.__name__}",
            )
            return 1

    owner = read_owner(state_file)
    if owner == session_id:
        return 0

    outcome = start_new_chat()

    try:
        write_owner(state_file, session_id)
    except OSError as error:
        append_log(
            log_file,
            f"write-failed event={event or 'hook'} error={error.__class__.__name__}",
        )
        return 1

    append_log(
        log_file,
        f"{event or 'hook'} source={source or '-'} session={session_id} "
        f"previous={owner or '-'} outcome={outcome}",
    )
    return 0 if outcome != "reset-failed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
