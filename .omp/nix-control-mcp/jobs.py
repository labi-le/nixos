import json
import os
import subprocess
import time
from pathlib import Path

from config import JOBS, LOG_TAIL_BYTES, MAX_JOBS, REPO
from protocol import CANCELLED, progress
from text import tail


JOB_CHILDREN = {}


def job_dir():
    JOBS.mkdir(parents=True, exist_ok=True)
    return JOBS


def job_meta_path(job):
    return job_dir() / f"{job}.json"


def job_log_path(job):
    return job_dir() / f"{job}.log"


def allocate_job(action):
    base = "%s-%s" % (action.replace("-", "_"), time.strftime("%Y%m%d-%H%M%S"))
    job = base
    suffix = 1
    while True:
        try:
            os.close(os.open(str(job_log_path(job)), os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o644))
            return job
        except FileExistsError:
            suffix += 1
            job = f"{base}-{suffix}"


def job_rc_path(job):
    return job_dir() / f"{job}.rc"


def start_job(action, argv):
    job = allocate_job(action)
    log = job_log_path(job)
    handle = open(log, "wb")
    handle.write(("$ " + " ".join(argv) + "\n").encode())
    handle.flush()
    wrapped = [
        "/bin/sh",
        "-c",
        'rc=0; "$@" || rc=$?; printf %s "$rc" > "$0"; exit "$rc"',
        str(job_rc_path(job)),
    ] + argv
    child = subprocess.Popen(
        wrapped,
        cwd=str(REPO),
        stdin=subprocess.DEVNULL,
        stdout=handle,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    handle.close()
    meta = {
        "job": job,
        "action": action,
        "command": argv,
        "pid": child.pid,
        "log": str(log),
        "started": time.strftime("%Y-%m-%d %H:%M:%S"),
        "state": "running",
    }
    job_meta_path(job).write_text(json.dumps(meta, indent=2))
    JOB_CHILDREN[job] = child
    return child, meta


def finish_job(meta, code, seconds):
    meta["state"] = "exited" if code is not None else "detached"
    meta["exit_code"] = code
    meta["duration_s"] = round(seconds, 1)
    job_meta_path(meta["job"]).write_text(json.dumps(meta, indent=2))
    return meta


def process_alive(pid):
    try:
        fields = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[-1].split()
    except OSError:
        return False
    return bool(fields) and fields[0] != "Z"


def recorded_exit_code(job):
    try:
        return int(job_rc_path(job).read_text().strip())
    except (OSError, ValueError):
        return None


def refresh_job(meta):
    if meta.get("state") not in ("running", "detached"):
        return meta
    job = meta["job"]
    child = JOB_CHILDREN.get(job)
    if child is not None and child.poll() is None:
        return meta
    recorded = recorded_exit_code(job)
    if recorded is not None:
        meta["state"] = "exited"
        meta["exit_code"] = recorded
    elif child is not None:
        meta["state"] = "exited"
        meta["exit_code"] = child.returncode
    elif meta.get("pid") and not process_alive(meta["pid"]):
        meta["state"] = "finished"
        meta["exit_code_note"] = "process is gone and wrote no exit code; read the log tail"
    else:
        return meta
    job_meta_path(job).write_text(json.dumps(meta, indent=2))
    return meta


def await_job(child, meta, wait_s, request_id, token):
    started = time.monotonic()
    step = 0
    while True:
        code = child.poll()
        if code is not None:
            return code, time.monotonic() - started
        if str(request_id) in CANCELLED:
            return None, time.monotonic() - started
        if time.monotonic() - started >= wait_s:
            return None, time.monotonic() - started
        time.sleep(1.0)
        step += 1
        if token is not None and step % 5 == 0:
            progress(token, step, tail(read_log(meta["job"]), 1) or meta["action"])


def read_log(job, limit=LOG_TAIL_BYTES):
    path = job_log_path(job)
    if not path.exists():
        return ""
    size = path.stat().st_size
    with path.open("rb") as handle:
        if size > limit:
            handle.seek(size - limit)
        chunk = handle.read()
    text = chunk.decode("utf-8", "replace")
    if size > limit:
        return "[log truncated to the last %d bytes of %d]\n" % (limit, size) + text
    return text


def known_jobs():
    if not JOBS.exists():
        return []
    metas = []
    for path in sorted(JOBS.glob("*.json"))[-MAX_JOBS:]:
        try:
            metas.append(json.loads(path.read_text()))
        except ValueError:
            continue
    metas.sort(key=lambda meta: meta.get("started", ""))
    return metas
