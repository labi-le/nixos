import json
import os
import signal
import sys
import threading

from jobs import job_dir
from pane import purge_scratch
from protocol import INFLIGHT
from server import handle


def terminate(signum, frame):
    purge_scratch()
    os._exit(0)


def main():
    job_dir()
    signal.signal(signal.SIGTERM, terminate)
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            message = json.loads(line)
        except ValueError:
            continue
        if not isinstance(message, dict):
            continue
        if message.get("method") == "initialize":
            handle(message)
            continue
        request_id = message.get("id")
        if request_id is not None:
            INFLIGHT.add(str(request_id))
        threading.Thread(target=handle, args=(message,), daemon=False).start()


if __name__ == "__main__":
    main()
