#!/usr/bin/env python3
"""Keep the local FreeDeepseekAPI agent key in sync with the jcode session.

jcode hooks (session_start, turn_start) call this script. It gives every jcode
session its own agent key on the local proxy and drops the chat the previous
session used, so a cleared jcode session also starts from an empty DeepSeek
chat. The key is handed to jcode through the provider env file, which the
provider reads when it is built for a session.
"""

from __future__ import annotations

import json
import os
import re
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

PROFILE = os.environ.get("FDS_PROFILE", "deepseek-web")
PROXY = os.environ.get("FDS_PROXY", "http://127.0.0.1:9655").rstrip("/")
KEY_PREFIX = os.environ.get("FDS_KEY_PREFIX", "jcode")
FALLBACK_KEY = os.environ.get("FDS_FALLBACK_KEY", "jcode")
ENV_FILE_NAME = os.environ.get("FDS_ENV_FILE", "deepseek-web.env")

ENV_KEY = "JCODE_OPENAI_EXTRA_BODY"
STATE_FILE_NAME = "deepseek-session.state"
LOG_FILE_NAME = "deepseek-session.log"
LOG_LIMIT_BYTES = 64 * 1024


def config_dir() -> Path:
    base = os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")
    return Path(base) / "jcode"


def agent_key(session_id: str) -> str:
    return f"{KEY_PREFIX}-{session_id}"


def current_key(env_file: Path) -> str:
    try:
        content = env_file.read_text()
    except OSError:
        return FALLBACK_KEY
    match = re.search(r'"session"\s*:\s*"([^"]*)"', content)
    return match.group(1) if match else FALLBACK_KEY


def live_sessions() -> set[str]:
    try:
        with urllib.request.urlopen(f"{PROXY}/v1/sessions", timeout=5) as response:
            payload = json.load(response)
    except (OSError, ValueError, urllib.error.URLError):
        return set()
    return {
        entry.get("agent", "")
        for entry in payload.get("agents", [])
        if entry.get("session_id")
    }


def reset_session(name: str) -> bool:
    request = urllib.request.Request(
        f"{PROXY}/reset-session?agent={urllib.parse.quote(name)}", method="POST"
    )
    try:
        with urllib.request.urlopen(request, timeout=5):
            return True
    except (OSError, urllib.error.URLError):
        return False


def write_env_file(env_file: Path, key: str) -> None:
    lines = []
    try:
        lines = [
            line
            for line in env_file.read_text().splitlines()
            if not line.startswith(f"{ENV_KEY}=")
        ]
    except OSError:
        pass
    lines.append(f'{ENV_KEY}={{"session":"{key}"}}')
    tmp = env_file.with_name(env_file.name + f".tmp{os.getpid()}")
    tmp.write_text("\n".join(lines) + "\n")
    tmp.chmod(0o600)
    tmp.replace(env_file)


def append_log(log_file: Path, message: str) -> None:
    try:
        with log_file.open("a") as handle:
            handle.write(message + "\n")
        if log_file.stat().st_size > LOG_LIMIT_BYTES:
            tail = log_file.read_text().splitlines()[-200:]
            log_file.write_text("\n".join(tail) + "\n")
    except OSError:
        pass


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
    in_use = current_key(env_file)
    try:
        state = state_file.read_text().splitlines()
    except OSError:
        state = []
    previous_session = state[0] if state else ""
    previous_key = state[1] if len(state) > 1 else ""

    if session_id == previous_session and in_use == key:
        return 0

    cleared = []
    if previous_session or event == "session_start":
        try:
            live = live_sessions()
        except Exception:
            live = set()
        stale = {name for name in (in_use, previous_key) if name and name != key}
        cleared = sorted(name for name in stale if name in live)
        for name in cleared:
            reset_session(name)

    write_env_file(env_file, key)
    try:
        state_file.write_text(f"{session_id}\n{in_use}\n")
    except OSError:
        pass

    append_log(
        log_file,
        f"{event or 'hook'} source={source or '-'} key={key} "
        f"in_use={in_use} previous={previous_session or '-'} cleared={','.join(cleared) or '-'}",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
