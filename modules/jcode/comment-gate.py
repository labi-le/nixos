#!/usr/bin/env python3
import json
import os
import re
import sys

CODE_EXT = {
    "ts", "tsx", "js", "jsx", "mjs", "cjs", "vue", "svelte", "astro", "scss",
    "less", "php", "py", "rb", "pl", "lua", "go", "rs", "zig", "c", "h", "cc",
    "cpp", "hpp", "cs", "java", "kt", "kts", "scala", "groovy", "gradle",
    "swift", "dart", "ex", "exs", "hs", "jl", "r", "sol", "proto", "sh",
    "bash", "zsh", "ps1", "nix", "tf", "tfvars", "hcl", "sql", "yaml", "yml",
    "toml",
}

COMMENT_PREFIX = ("//", "#", "--", ";", "/*", "*", "<!--")
EDIT_TOOLS = {"write", "edit", "multiedit", "patch", "apply_patch"}

MARKERS = re.compile(r"\b(TODO|FIXME|XXX|HACK)\b")
EMAIL = re.compile(r"\b[\w.%+-]+@[\w-]+\.[A-Za-z][A-Za-z]+\b")
IPV4 = re.compile(r"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b")
HOME_PATH = re.compile(r"/home/[A-Za-z_][\w.-]*")
INTERNAL_HOST = re.compile(r"\b[\w-]+\.(?:internal|intranet|corp|lan|prod|prd|stage|stg)\b")
SECRET = re.compile(
    r"(sk-[A-Za-z0-9]{16,}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}"
    r"|AKIA[0-9A-Z]{12,}|xox[baprs]-[A-Za-z0-9-]{10,}"
    r"|(?i:bearer)\s+[A-Za-z0-9._-]{20,}"
    r"|\b[A-Za-z0-9+/]{40,}={0,2}\b)"
)
CODE_SHAPE = re.compile(r"\b(let|const|var|def|fn|func|function|return|import|pub|class|if|for|while)\b")

SAFE_IP = {"127.0.0.1", "0.0.0.0", "255.255.255.255", "192.0.2.1"}
SAFE_HOST = re.compile(r"(example\.(com|org|net)|localhost)")
SAFE_EMAIL = re.compile(r"(user@example\.com|@example\.(com|org|net))")


def fail(reason):
    sys.stderr.write(reason.strip() + "\n")
    sys.exit(2)


def allow():
    sys.exit(0)


def is_comment(line):
    stripped = line.strip()
    return bool(stripped) and stripped.startswith(COMMENT_PREFIX)


def comment_text(line):
    stripped = line.strip()
    for prefix in COMMENT_PREFIX:
        if stripped.startswith(prefix):
            return stripped[len(prefix):].strip()
    return stripped


def looks_like_code(text):
    if not text or not re.search(r"[A-Za-z0-9_]", text):
        return False
    if text.endswith((";", ")", "}", "=>", "->")):
        return True
    if CODE_SHAPE.search(text):
        return True
    if "=" in text and re.search(r"[;(){}]", text):
        return True
    return False


def added_lines(text):
    if any(line.startswith("@@") for line in text.splitlines()):
        return "\n".join(
            line[1:]
            for line in text.splitlines()
            if line.startswith("+") and not line.startswith("+++")
        )
    return text


def check_added_text(text, path):
    text = added_lines(text)
    extension = path.rsplit(".", 1)[-1].lower() if "." in os.path.basename(path) else ""
    if extension not in CODE_EXT:
        allow()

    comment_lines = []
    for line in text.splitlines():
        if is_comment(line):
            comment_lines.append(comment_text(line))
        else:
            comment_lines.append(None)

    consecutive = 0
    for line in text.splitlines():
        if is_comment(line) and looks_like_code(comment_text(line)):
            consecutive += 1
            if consecutive >= 2:
                fail("comment-gate: commented-out code was added; git remembers deleted code, delete it instead")
        else:
            consecutive = 0

    for raw, body in zip(text.splitlines(), comment_lines):
        if body is None:
            continue
        if MARKERS.search(body):
            fail("comment-gate: scaffolding marker found in an added comment; remove TODO/FIXME/XXX/HACK")
        if looks_like_code(body):
            fail("comment-gate: commented-out code found in an added comment; delete it instead of commenting it out")
        if SECRET.search(body):
            fail("comment-gate: credential-shaped value found in an added comment; never paste credentials")
        if HOME_PATH.search(body):
            fail("comment-gate: absolute home path found in an added comment; use a neutral example path")
        if INTERNAL_HOST.search(body) and not SAFE_HOST.search(body):
            fail("comment-gate: internal hostname found in an added comment; use example.com in examples")
        for match in IPV4.findall(body):
            if match not in SAFE_IP:
                fail("comment-gate: real IP address found in an added comment; use 192.0.2.1 in examples")
        for match in EMAIL.findall(body):
            if not SAFE_EMAIL.search(match):
                fail("comment-gate: real email address found in an added comment; use user@example.com in examples")


def edited_parts(payload):
    parts = []
    for key in ("content", "new_string", "text", "patch_text"):
        value = payload.get(key)
        if isinstance(value, str):
            parts.append(value)
    for key in ("edits", "edits_list"):
        value = payload.get(key)
        if isinstance(value, list):
            for item in value:
                if isinstance(item, dict):
                    for sub in ("new_string", "content"):
                        if isinstance(item.get(sub), str):
                            parts.append(item[sub])
    return parts


def edited_path(payload):
    path = payload.get("file_path") or payload.get("path") or ""
    if not isinstance(path, str):
        path = ""
    edits = payload.get("edits")
    if isinstance(edits, list):
        for item in edits:
            if isinstance(item, dict) and isinstance(item.get("file_path"), str):
                return item["file_path"]
    return path


def main():
    try:
        raw = sys.stdin.read()
    except Exception:
        allow()
    try:
        payload = json.loads(raw) if raw.strip() else {}
    except Exception:
        payload = {}

    tool = os.environ.get("JCODE_HOOK_TOOL_NAME", "").strip().lower()
    if tool not in EDIT_TOOLS:
        allow()

    parts = edited_parts(payload)
    if parts:
        check_added_text("\n".join(parts), edited_path(payload))
    allow()


if __name__ == "__main__":
    main()
