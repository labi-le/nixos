#!/usr/bin/env python3
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

JCODE = pathlib.Path(__file__).resolve().parent
GATE = JCODE / "gates.py"
UPSTREAM = JCODE / "git_upstream_gate.py"
REGISTER = JCODE / "repo-register.sh"

COMMIT_CASES = [
    ('git commit -qm "test: seed"', 0),
    ('git commit -m "test: seed"', 0),
    ('git commit -m "wip"', 2),
    ('git commit -m "fixed stuff"', 2),
    ('git commit -qam "jcode: fix thing"', 0),
    ('git commit --message="jcode: fix thing"', 0),
    ('git commit -mjcode:fix', 2),
    ('git commit -m "a: b" -m "c"', 2),
    ('git commit -m "a(x): b"', 2),
    ('git commit -m "jcode: trailing."', 2),
    ('git commit -m "jcode: body\n\nmore"', 2),
    ('git commit --amend --no-edit', 2),
    ('git commit --dry-run', 0),
    ('git commit -F msg.txt', 2),
    ('git commit -m "$(cat msg.txt)"', 2),
    ('git commit -m "jcode: ok" && git status', 0),
    ('echo git commit -m "not really"', 0),
    ('sudo git commit -m "wip"', 2),
    ('sudo git commit -m "jcode: ok"', 0),
    ("""bash -c 'git commit -m "jcode: ok"'""", 0),
]

PUSH_CASES = [
    ("git push", 2),
    ("git push -u origin feature/x", 0),
    ("git push origin HEAD", 2),
    ("git push --dry-run", 0),
    ("git push --force", 2),
    ("git push upstream main", 2),
    ("git push --force-with-lease origin main", 2),
    ("git push --force-with-lease=main origin main", 2),
    ("git status", 0),
    ("cd /nonexistent && git push", 0),
    ("git checkout -B feature/y origin/main && git push", 0),
    ('git commit -m "jcode: ok" && git push', 2),
]

COMMENT_CASES = [
    ("write", {"file_path": "src/a.rs", "content": "fn main() {}\n// TODO: fix"}, 2),
    ("write", {"file_path": "src/a.rs", "content": "fn main() {}"}, 0),
    ("write", {"file_path": "README.md", "content": "// TODO: fix"}, 0),
    ("write", {"file_path": "test.sh", "content": "case x in\n  a) echo 1;;\nesac\n"}, 0),
    ("write", {"file_path": "src/a.rs", "content": "// prose line one\n// prose line two"}, 0),
    ("edit", {"file_path": "src/a.py", "new_string": "# see /home/someone/x"}, 2),
    ("apply_patch", {"file_path": "src/a.rs", "patch_text": "@@ -1 +1 @@\n-// TODO: x\n+fn main() {}"}, 0),
]

REGISTER_CASES = [
    ("git repo start", {"cwd": "repo", "mode": "start", "env": {}}, "register"),
    ("non-git start", {"cwd": "plain", "mode": "start", "env": {}}, None),
    ("disabled start", {"cwd": "repo", "mode": "start", "env": {"CODE_INDEXER_DISABLE": "1"}}, None),
    ("no-code-index start", {"cwd": "repo", "mode": "start", "env": {}, "marker": True}, None),
    ("stop", {"cwd": "repo", "mode": "stop", "env": {}}, "unregister"),
]


def gate(script, tool, payload, cwd=None):
    env = dict(os.environ)
    env["JCODE_HOOK_TOOL_NAME"] = tool
    if cwd:
        env["JCODE_HOOK_CWD"] = str(cwd)
    proc = subprocess.run(
        [sys.executable, str(script)],
        input=json.dumps(payload),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
    )
    first = (proc.stderr.strip().splitlines() or [""])[0]
    return proc.returncode, first


def make_repo(root):
    repo = root / "repo"
    repo.mkdir(parents=True)
    git = ["git", "-C", str(repo)]
    subprocess.run(git + ["init", "-q"], check=True)
    subprocess.run(git + ["config", "user.email", "user@example.com"], check=True)
    subprocess.run(git + ["config", "user.name", "test"], check=True)
    (repo / "a.txt").write_text("x")
    subprocess.run(git + ["add", "a.txt"], check=True)
    subprocess.run(git + ["commit", "-qm", "test: seed"], check=True)
    subprocess.run(git + ["remote", "add", "origin", "https://example.com/repo.git"], check=True)
    subprocess.run(git + ["branch", "-M", "main"], check=True)
    head = subprocess.run(git + ["rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    subprocess.run(git + ["update-ref", "refs/remotes/origin/main", head], check=True)
    subprocess.run(git + ["checkout", "-qb", "feature/x"], check=True)
    subprocess.run(git + ["branch", "-u", "origin/main", "feature/x"], check=True)
    return repo


def check_report(failures, label, ok, detail):
    print(f"{'ok  ' if ok else 'FAIL'} {label} {detail}")
    return failures + (0 if ok else 1)


def main():
    fixture_root = os.environ.get("JCODE_GATE_MATRIX_DIR") or "/tmp"
    root = pathlib.Path(tempfile.mkdtemp(prefix="jcode-gate-matrix-", dir=fixture_root))
    failures = 0
    try:
        repo = make_repo(root)
        (root / "plain").mkdir()
        (root / "bin").mkdir()
        stub = root / "bin" / "index-repo"
        stub.write_text(f'#!/bin/sh\nprintf "%s\\n" "$*" >> "{root}/calls.txt"\n')
        stub.chmod(0o755)

        print("== commit gate")
        for command, expected in COMMIT_CASES:
            code, message = gate(GATE, "bash", {"command": command, "cwd": str(repo)})
            failures = check_report(failures, f"exit={code} want={expected}", code == expected, command[:60])

        print("== upstream gate")
        for command, expected in PUSH_CASES:
            code, message = gate(UPSTREAM, "bash", {"command": command}, cwd=repo)
            failures = check_report(failures, f"exit={code} want={expected}", code == expected, command[:60])

        print("== comment gate")
        for tool, payload, expected in COMMENT_CASES:
            code, message = gate(GATE, tool, payload)
            failures = check_report(failures, f"exit={code} want={expected}", code == expected, f"{tool} {payload.get('file_path')}")

        print("== repo register hook")
        calls = root / "calls.txt"
        for label, case, expected_call in REGISTER_CASES:
            if case.get("marker"):
                (repo / ".no-code-index").write_text("")
            if calls.exists():
                calls.unlink()
            env = dict(os.environ)
            env["JCODE_HOOK_CWD"] = str(root / case["cwd"])
            env["REPO_REGISTER_INDEX_REPO"] = str(stub)
            for key, value in case["env"].items():
                env[key] = value
            proc = subprocess.run(["/bin/sh", str(REGISTER), case["mode"]], env=env, text=True, capture_output=True)
            if (repo / ".no-code-index").exists():
                (repo / ".no-code-index").unlink()
            recorded = calls.read_text().strip().splitlines() if calls.exists() else []
            ok = True
            detail = f"{label}: exit={proc.returncode} calls={recorded}"
            if recorded and expected_call not in recorded[0]:
                ok = False
            if not recorded and expected_call:
                ok = False
            failures = check_report(failures, label, ok, detail)

        print("failures:", failures)
        return 1 if failures else 0
    finally:
        shutil.rmtree(root, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
