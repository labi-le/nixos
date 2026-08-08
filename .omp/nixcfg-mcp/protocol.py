import json
import sys
import threading

OUT_LOCK = threading.Lock()
CANCELLED = set()


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
