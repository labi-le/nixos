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
SAFE_IP = {"127.0.0.1", "0.0.0.0", "255.255.255.255", "192.0.2.1"}
SAFE_HOST = re.compile(r"(example\.(com|org|net)|localhost)")
SAFE_EMAIL = re.compile(r"(user@example\.com|@example\.(com|org|net))")
COMPONENT = re.compile(r"^[A-Za-z0-9][\w.-]*(?::[\w.-]+)?: \S")
EDIT_TOOLS = {"write", "edit", "multiedit", "patch", "apply_patch"}
BASH_TOOLS = {"bash", "execute", "run", "shell"}


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
    if re.search(r"\b(let|const|var|def|fn|func|function|return|import|pub|class|if|for|while)\b", text):
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


def split_commands(text):
    segments = []
    token = ""
    quote = None
    escaped = False
    at = 0
    while at < len(text):
        ch = text[at]
        if escaped:
            token += ch
            escaped = False
            at += 1
            continue
        if ch == "\\" and quote != "'":
            token += ch
            escaped = True
            at += 1
            continue
        if quote:
            token += ch
            if ch == quote:
                quote = None
            at += 1
            continue
        if ch in ("'", '"'):
            quote = ch
            token += ch
            at += 1
            continue
        two = text[at : at + 2]
        if two in ("&&", "||"):
            segments.append(token)
            token = ""
            at += 2
            continue
        if ch in (";", "|", "\n"):
            segments.append(token)
            token = ""
            at += 1
            continue
        token += ch
        at += 1
    segments.append(token)
    return segments

def split_shell(text):
    words = []
    token = ""
    quote = None
    escaped = False
    for ch in text:
        if escaped:
            token += ch
            escaped = False
        elif ch == "\\" and quote != "'":
            escaped = True
        elif quote:
            if ch == quote:
                quote = None
            else:
                token += ch
        elif ch in ("'", '"'):
            quote = ch
        elif ch.isspace():
            if token:
                words.append(token)
                token = ""
        else:
            token += ch
    if token:
        words.append(token)
    return words


WRAPPERS = {"sudo", "doas", "env", "command", "nice", "ionice", "time", "xargs", "ssh"}


def git_commit_command(command):
    for segment in split_commands(command):
        words = split_shell(segment)
        at = 0
        while at < len(words) and words[at] in WRAPPERS:
            at += 1
            while at < len(words) and words[at].startswith("-"):
                pair = words[at] in ("-u", "-g", "-C", "-p", "--user", "--group")
                at += 2 if pair else 1
            if at < len(words) and words[at] == "--":
                at += 1
        if at >= len(words):
            continue
        words = words[at:]
        if words[0] != "git" and not words[0].endswith("/git"):
            continue
        tail = words[1:]
        at = 0
        while at < len(tail) and tail[at].startswith("-"):
            at += 2 if tail[at] in ("-C", "-c") else 1
        if at < len(tail) and tail[at] == "commit":
            return words
    return None


EXEMPT = {
    "--dry-run", "--fixup", "--squash", "-C", "--reuse-message", "-c", "--reedit-message",
}
TAKE_VALUE = {"-F", "--file", "-t", "--template", "-C", "-c", "--reuse-message", "--reedit-message"}
TRAILER = re.compile(r"^(co-authored-by:|generated with\b)|\U0001f916", re.I | re.M)


def commit_invocation(words):
    git_at = next((i for i, w in enumerate(words) if w == "git" or w.endswith("/git")), -1)
    if git_at == -1:
        return None
    at = git_at + 1
    globals_ = []
    while at < len(words) and words[at].startswith("-"):
        pair = words[at] in ("-C", "-c")
        globals_.append(words[at])
        if pair and at + 1 < len(words):
            globals_.append(words[at + 1])
        at += 2 if pair else 1
    if at >= len(words) or words[at] != "commit":
        return None

    invocation = {"messages": [], "indirect": None, "exempt": False}
    for token in words[:git_at]:
        if re.match(r"^((GIT_)?(EDITOR|VISUAL|SEQUENCE_EDITOR)|GIT_CONFIG\w*)=", token):
            invocation["indirect"] = "an environment override (`%s`)" % token.split("=")[0]
    for token in globals_:
        hit = re.search(r"(^|=)(core\.editor|sequence\.editor|commit\.template)=", token, re.I)
        if hit:
            invocation["indirect"] = "a config override (`%s`)" % hit.group(2).lower()

    at += 1
    while at < len(words):
        token = words[at]
        if token in EXEMPT or token.startswith("--fixup=") or token.startswith("--squash="):
            invocation["exempt"] = True
            at += 1
            continue
        cluster = "" if token.startswith("--") else token.split("m")[0]
        if token == "--edit" or re.match(r"^-[a-zA-Z]*e", cluster or "x"):
            invocation["indirect"] = "`--edit`, which hands the message to an editor"
            at += 1
            continue
        if token == "--message" or re.match(r"^-[a-zA-Z]*m$", token):
            if at + 1 < len(words):
                invocation["messages"].append(words[at + 1])
                at += 2
            else:
                at += 1
            continue
        if token.startswith("--message="):
            invocation["messages"].append(token[len("--message="):])
            at += 1
            continue
        attached = re.match(r"^-[a-zA-Z]*m(.+)$", token)
        if attached:
            invocation["messages"].append(attached.group(1))
            at += 1
            continue
        if token in ("--file", "-F", "--template", "-t"):
            invocation["indirect"] = "`%s`" % token
            at += 2
            continue
        if token.startswith("--file=") or token.startswith("--template="):
            invocation["indirect"] = "`%s`" % token.split("=")[0]
            at += 1
            continue
        at += 1
    return invocation


def check_commit(command):
    words = git_commit_command(command)
    if not words:
        return
    invocation = commit_invocation(words)
    if invocation is None or invocation["exempt"]:
        return
    if invocation["indirect"]:
        fail(
            "commit-gate: the message would come from %s instead of the command line; "
            "pass the literal text in a single `-m` so what git records can be read" % invocation["indirect"]
        )
    messages = invocation["messages"]
    if not messages:
        fail(
            "commit-gate: the commit carries no `-m`, so the message would come from git's editor buffer "
            "and cannot be read here; pass the literal text in a single `-m`"
        )
    if len(messages) > 1:
        fail("commit-gate: the message is split across repeated `-m` flags; pass a single `-m` holding one line")

    message = messages[0]
    if "$" in message or "`" in message:
        fail("commit-gate: the message is assembled by the shell; pass the literal text")
    subject = message.split("\n")[0]
    if re.match(r"^(merge|revert|fixup!|squash!|amend!)\b", subject, re.I):
        return
    if "\n" in message.strip():
        fail("commit-gate: the message is one line only; a decision the diff cannot show belongs in `docs/`")
    if not subject.strip():
        fail("commit-gate: the subject is empty")
    if re.match(r"^[a-zA-Z]+\([^)]*\):", subject):
        fail(
            "commit-gate: the conventional-commits `type(scope):` form is not used here; the prefix is "
            "a component such as `jcode:`, `omp:` or `server:`"
        )
    word = r"[a-zA-Z0-9][a-zA-Z0-9._/-]*"
    if not re.match(r"^%s( %s){0,2}: \S" % (word, word), subject):
        fail("commit-gate: the subject is not `component: what changed`, with at most three words before the colon")
    if len(subject) > 70:
        fail("commit-gate: the subject is %d characters; 70 is the hard ceiling" % len(subject))
    if subject.endswith("."):
        fail("commit-gate: the subject ends with a period")
    trailer = TRAILER.search(message)
    if trailer:
        fail("commit-gate: the message carries a generated trailer (`%s`)" % trailer.group(0).strip())


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
    if not tool:
        allow()

    if tool in BASH_TOOLS:
        command = payload.get("command") or ""
        if not isinstance(command, str):
            allow()
        commit = git_commit_command(command)
        if commit:
            check_commit(command)
        allow()

    if tool in EDIT_TOOLS:
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
        path = payload.get("file_path") or payload.get("path") or ""
        if not isinstance(path, str):
            path = ""
        for key in ("edits",):
            value = payload.get(key)
            if isinstance(value, list):
                for item in value:
                    if isinstance(item, dict) and isinstance(item.get("file_path"), str):
                        path = item["file_path"]
                        break
        if parts:
            check_added_text("\n".join(parts), path)
        allow()

    allow()


if __name__ == "__main__":
    main()
