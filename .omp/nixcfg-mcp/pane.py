import os
import shlex
import shutil
import tempfile
import time
from pathlib import Path

from config import SUDO_PANE
from protocol import ToolError
from shell import run_split
from text import tail


def tmux_socket():
    inside = os.environ.get("TMUX", "")
    if inside:
        return inside.split(",")[0]
    bases = [
        os.environ.get("TMUX_TMPDIR"),
        os.environ.get("XDG_RUNTIME_DIR"),
        "/tmp",
    ]
    for base in bases:
        if not base:
            continue
        candidate = Path(base) / f"tmux-{os.getuid()}" / "default"
        if candidate.exists():
            return str(candidate)
    return None


def tmux_argv(*args):
    socket = tmux_socket()
    return ["tmux"] + (["-S", socket] if socket else []) + list(args)


def pane_alive():
    code, _, _ = run_split(tmux_argv("has-session", "-t", SUDO_PANE), timeout=30)
    return code == 0


def run_in_pane(argv, timeout=120):
    if not pane_alive():
        raise ToolError(
            f"this needs the root-owned host key, so it runs in the persistent `{SUDO_PANE}` "
            "tmux pane where your sudo credential is cached, and that pane does not exist. "
            f"Create it with `tmux new-session -d -s {SUDO_PANE}`, open it (from inside tmux "
            f"press Ctrl-a s and pick {SUDO_PANE}, otherwise `tmux attach -t {SUDO_PANE}`), "
            "run `sudo -v`, then detach with Ctrl-a d."
        )
    base = os.environ.get("XDG_RUNTIME_DIR") or tempfile.gettempdir()
    scratch = tempfile.mkdtemp(prefix="nixcfg-pane-", dir=base)
    try:
        out_path = Path(scratch) / "out"
        err_path = Path(scratch) / "err"
        rc_path = Path(scratch) / "rc"
        quoted = " ".join(shlex.quote(part) for part in argv)
        line = (
            f"{quoted} >{shlex.quote(str(out_path))} 2>{shlex.quote(str(err_path))}; "
            f"printf %s $? >{shlex.quote(str(rc_path))}"
        )
        send = run_split(tmux_argv("send-keys", "-t", SUDO_PANE, line, "Enter"), timeout=30)
        if send[0] != 0:
            raise ToolError(f"tmux send-keys failed:\n{tail(send[2], 4)}")
        deadline = time.monotonic() + timeout
        while not rc_path.exists():
            if time.monotonic() > deadline:
                raise ToolError(f"no result from the {SUDO_PANE} pane after {timeout}s")
            time.sleep(0.2)
        try:
            code = int(rc_path.read_text().strip())
        except ValueError:
            code = 1
        out = out_path.read_bytes() if out_path.exists() else b""
        err = err_path.read_text("utf-8", "replace") if err_path.exists() else ""
    finally:
        shutil.rmtree(scratch, ignore_errors=True)
    if code != 0 and "password is required" in err:
        raise ToolError(
            f"the `{SUDO_PANE}` pane has no cached sudo credential. Attach to it "
            f"(tmux attach -t {SUDO_PANE}), run `sudo -v`, detach with Ctrl-a d, and retry."
        )
    return code, out, err
