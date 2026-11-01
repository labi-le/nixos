#!/usr/bin/env python3
import hashlib
import json
import os
import socket
import subprocess
import sys

SOCKET_PATH = os.environ.get("CARGO_SLOT_SOCKET", "/run/cargo-slot/socket")
ALLOWED_ROOTS = tuple(
    root
    for root in os.environ.get(
        "CARGO_SLOT_ALLOWED_ROOTS", "/drive/state/buer/workspaces:/drive/code"
    ).split(":")
    if root
)
MAX_REQUEST = 1 << 16


def translate(path: str) -> str:
    mappings = os.environ.get(
        "CARGO_SLOT_PATH_MAP", "/data/workspaces:/drive/state/buer/workspaces"
    )
    for pair in mappings.split(";"):
        if ":" not in pair:
            continue
        source, target = pair.split(":", 1)
        if path == source or path.startswith(source + "/"):
            return target + path[len(source):]
    return path


def allowed(path: str) -> bool:
    if not path:
        return False
    real = os.path.realpath(path)
    return any(real == root or real.startswith(root + "/") for root in ALLOWED_ROOTS)


def stage(path: str):
    root = os.environ.get("CARGO_SLOT_STAGING", "/var/lib/cargo-slot/staging")
    target = os.path.join(root, hashlib.sha256(path.encode()).hexdigest()[:16])
    os.makedirs(root, exist_ok=True)
    sync = subprocess.run(
        [
            "rsync",
            "-a",
            "--delete",
            "--exclude",
            "target",
            "--exclude",
            ".git",
            path.rstrip("/") + "/",
            target + "/",
        ],
        capture_output=True,
        text=True,
    )
    if sync.returncode != 0:
        return None
    subprocess.run(["chown", "-R", "labile:users", target], capture_output=True)
    return target


def handle(cwd: str, args: list[str], extra: dict) -> dict:
    cwd = translate(cwd)
    if not allowed(cwd) or not args or args[0] != "cargo":
        return {"rc": 2, "output": "cargo-slot relay: denied"}
    work = stage(cwd)
    if work is None:
        return {"rc": 2, "output": "cargo-slot relay: staging failed"}
    env = {
        "PATH": os.environ.get("PATH", "/run/current-system/sw/bin"),
        "HOME": os.environ.get("CARGO_SLOT_HOME", "/var/lib/cargo-slot/home"),
    }
    env.update({key: value for key, value in extra.items() if isinstance(value, str)})
    proc = subprocess.run(
        [
            "setpriv",
            "--reuid=labile",
            "--regid=users",
            "--init-groups",
            "cargo-slot",
            *args,
        ],
        cwd=work,
        env=env,
        capture_output=True,
        text=True,
    )
    return {"rc": proc.returncode, "output": (proc.stdout or "") + (proc.stderr or "")}


def serve() -> int:
    os.makedirs(os.path.dirname(SOCKET_PATH), exist_ok=True)
    if os.path.exists(SOCKET_PATH):
        os.unlink(SOCKET_PATH)
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(SOCKET_PATH)
    os.chmod(SOCKET_PATH, 0o666)
    server.listen(16)
    while True:
        conn, _ = server.accept()
        with conn:
            data = b""
            while not data.endswith(b"\n") and len(data) < MAX_REQUEST:
                chunk = conn.recv(65536)
                if not chunk:
                    break
                data += chunk
            try:
                request = json.loads(data.decode() or "{}")
            except (UnicodeDecodeError, json.JSONDecodeError):
                conn.sendall(b'{"rc":2,"output":"bad request"}\n')
                continue
            cwd = request.get("cwd") if isinstance(request.get("cwd"), str) else ""
            args = request.get("args") if isinstance(request.get("args"), list) else []
            args = [arg for arg in args if isinstance(arg, str)]
            extra = request.get("env") if isinstance(request.get("env"), dict) else {}
            try:
                reply = handle(cwd, args, extra)
            except Exception as error:
                reply = {"rc": 2, "output": f"cargo-slot relay: {type(error).__name__}"}
            conn.sendall(json.dumps(reply).encode() + b"\n")
    return 0


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--serve":
        sys.exit(serve())
    print("cargo-slot-relay: use --serve", file=sys.stderr)
    sys.exit(2)
