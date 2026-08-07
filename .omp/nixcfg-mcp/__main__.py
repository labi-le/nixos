import json
import sys
import threading

from jobs import job_dir
from server import handle


def main():
    job_dir()
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
        threading.Thread(target=handle, args=(message,), daemon=False).start()


if __name__ == "__main__":
    main()
