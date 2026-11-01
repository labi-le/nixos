#!/usr/bin/env python3
import json
import os
import socket
import sys

SOCKET_PATH = os.environ.get("CARGO_SLOT_SOCKET", "/run/cargo-slot/socket")


def request(args: list[str]) -> int:
    body = json.dumps(
        {
            "cwd": os.getcwd(),
            "args": args,
            "env": {
                key: value
                for key, value in os.environ.items()
                if key.startswith("CARGO_SLOT_")
            },
        }
    ).encode() + b"\n"
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.connect(SOCKET_PATH)
        client.sendall(body)
        data = b""
        while not data.endswith(b"\n"):
            chunk = client.recv(65536)
            if not chunk:
                break
            data += chunk
    try:
        reply = json.loads(data.decode() or "{}")
    except (UnicodeDecodeError, json.JSONDecodeError):
        print("cargo-slot relay: invalid reply", file=sys.stderr)
        return 2
    sys.stdout.write(reply.get("output") or "")
    return int(reply.get("rc") or 0)


if __name__ == "__main__":
    sys.exit(request(sys.argv[1:]))
