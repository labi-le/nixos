import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
import time
import urllib.request


LOKI_PUSH_URL = "http://127.0.0.1:3100/loki/api/v1/push"
MAX_FILE_BYTES = 100 * 1024 * 1024
ROTATE_COUNT = 5


def rotate_if_needed(path: Path) -> None:
    try:
        if not path.exists() or path.stat().st_size < MAX_FILE_BYTES:
            return
        for idx in range(ROTATE_COUNT - 1, 0, -1):
            src = path.with_suffix(path.suffix + f".{idx}")
            dst = path.with_suffix(path.suffix + f".{idx + 1}")
            if src.exists():
                os.replace(src, dst)
        os.replace(path, path.with_suffix(path.suffix + ".1"))
    except OSError:
        pass


def append_line(path: Path, line: str) -> None:
    rotate_if_needed(path)
    with path.open("a", encoding="utf-8") as fh:
        fh.write(line + "\n")


class LokiBatcher:
    def __init__(self, router: str):
        self.router = router
        self.lock = threading.Lock()
        self.streams = {}
        self.thread = threading.Thread(target=self._flush_loop, daemon=True)
        self.thread.start()

    def add(self, source: str, level: str, line: str) -> None:
        ts_ns = str(time.time_ns())
        key = (source, level)
        with self.lock:
            self.streams.setdefault(key, []).append([ts_ns, line])

    def _flush_loop(self) -> None:
        while True:
            time.sleep(2.0)
            self.flush()

    def flush(self) -> None:
        with self.lock:
            if not self.streams:
                return
            batch = self.streams
            self.streams = {}
        payload = {
            "streams": [
                {
                    "stream": {
                        "job": "openwrt-murmur",
                        "router": self.router,
                        "source": source,
                        "level": level,
                    },
                    "values": values,
                }
                for (source, level), values in batch.items()
            ]
        }
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        req = urllib.request.Request(
            LOKI_PUSH_URL,
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=5):
                pass
        except Exception as err:
            print(f"loki push warning: {type(err).__name__}", file=sys.stderr)


def ssh_base_args(target: str) -> list[str]:
    return [
        "ssh",
        "-F",
        "/dev/null",
        "-T",
        "-o",
        "IdentityAgent=none",
        "-o",
        "BatchMode=yes",
        "-o",
        "StrictHostKeyChecking=yes",
        "-o",
        "ConnectTimeout=5",
        "-o",
        "ServerAliveInterval=15",
        "-o",
        "ServerAliveCountMax=2",
        target,
    ]


REMOTE_MURMUR_STREAM = r'''set -eu
addr=$(sed -n "s/^[[:space:]]*external-controller:[[:space:]]*['\"]*\([^'\"]*\)['\"]*/\1/p" /etc/murmur/config.yaml 2>/dev/null | head -n 1)
case "$addr" in
    :*) CTRL="127.0.0.1$addr" ;;
    0.0.0.0:*) CTRL="127.0.0.1:${addr#0.0.0.0:}" ;;
    ?*:?*) CTRL="$addr" ;;
    *) CTRL="127.0.0.1:9090" ;;
esac
if [ -r /etc/murmur/controller.curl ]; then
    exec curl --config /etc/murmur/controller.curl -sSN --connect-timeout 5 --max-time 0 "http://$CTRL/logs?level=info&format=structured"
else
    exec curl -sSN --connect-timeout 5 --max-time 0 "http://$CTRL/logs?level=info&format=structured"
fi
'''


def stream_murmur_structured(target: str, log_dir: Path, batcher: LokiBatcher) -> None:
    out_file = log_dir / "murmur-structured.jsonl"
    while True:
        proc = None
        try:
            proc = subprocess.Popen(
                ssh_base_args(target) + ["/bin/ash", "-s"],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                encoding="utf-8",
                errors="replace",
            )
            assert proc.stdin is not None and proc.stdout is not None
            proc.stdin.write(REMOTE_MURMUR_STREAM)
            proc.stdin.close()
            for raw in proc.stdout:
                line = raw.strip()
                if not line:
                    continue
                level = "info"
                try:
                    parsed = json.loads(line)
                    if isinstance(parsed, dict) and isinstance(parsed.get("level"), str):
                        level = parsed["level"]
                except ValueError:
                    pass
                append_line(out_file, line)
                batcher.add("murmur", level, line)
        except Exception as err:
            print(f"murmur stream error: {type(err).__name__}", file=sys.stderr)
        finally:
            if proc is not None:
                try:
                    proc.terminate()
                    proc.wait(timeout=3)
                except Exception:
                    try:
                        proc.kill()
                    except Exception:
                        pass
        time.sleep(3.0)


def infer_syslog_level(line: str) -> str:
    lower = line.lower()
    if ".err " in lower or "level=error" in lower or "error" in lower:
        return "error"
    if ".warn " in lower or "level=warn" in lower or "warning" in lower:
        return "warn"
    return "info"


def stream_openwrt_logread(target: str, log_dir: Path, batcher: LokiBatcher) -> None:
    out_file = log_dir / "openwrt-syslog.log"
    while True:
        proc = None
        try:
            proc = subprocess.Popen(
                ssh_base_args(target) + ["/sbin/logread", "-f"],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                encoding="utf-8",
                errors="replace",
            )
            assert proc.stdout is not None
            for raw in proc.stdout:
                line = raw.rstrip("\r\n")
                if not line:
                    continue
                # Avoid duplicating routine murmur info lines that already arrive via structured stream,
                # while keeping all kernel/procd/netifd/oom/dnsmasq/awg events and murmur warnings/errors/startup.
                is_murmur_info = "daemon.info murmur[" in line and 'level=info msg="[' in line
                append_line(out_file, line)
                if not is_murmur_info:
                    batcher.add("syslog", infer_syslog_level(line), line)
        except Exception as err:
            print(f"logread stream error: {type(err).__name__}", file=sys.stderr)
        finally:
            if proc is not None:
                try:
                    proc.terminate()
                    proc.wait(timeout=3)
                except Exception:
                    try:
                        proc.kill()
                    except Exception:
                        pass
        time.sleep(3.0)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", required=True)
    parser.add_argument("--router", required=True)
    parser.add_argument("--log-dir", required=True, type=Path)
    args = parser.parse_args()
    args.log_dir.mkdir(parents=True, exist_ok=True)
    batcher = LokiBatcher(args.router)
    t1 = threading.Thread(target=stream_murmur_structured, args=(args.target, args.log_dir, batcher), daemon=True)
    t2 = threading.Thread(target=stream_openwrt_logread, args=(args.target, args.log_dir, batcher), daemon=True)
    t1.start()
    t2.start()
    while True:
        time.sleep(60.0)


if __name__ == "__main__":
    sys.exit(main())
