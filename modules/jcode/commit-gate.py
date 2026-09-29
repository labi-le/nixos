#!/usr/bin/env python3
import json
import os
import re
import sys

BASH_TOOLS = {"bash", "execute", "run", "shell"}
WRAPPERS = {"sudo", "doas", "env", "command", "nice", "ionice", "time", "xargs", "ssh"}
EXEMPT = {
    "--dry-run", "--fixup", "--squash", "-C", "--reuse-message", "-c", "--reedit-message",
}
TAKE_VALUE = {"-F", "--file", "-t", "--template", "-C", "-c", "--reuse-message", "--reedit-message"}
TRAILER = re.compile(r"^(co-authored-by:|generated with\b)|\U0001f916", re.I | re.M)


def fail(reason):
    sys.stderr.write(reason.strip() + "\n")
    sys.exit(2)


def allow():
    sys.exit(0)


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
    if tool not in BASH_TOOLS:
        allow()

    command = payload.get("command") or ""
    if not isinstance(command, str):
        allow()
    commit = git_commit_command(command)
    if commit:
        check_commit(command)
    allow()


if __name__ == "__main__":
    main()
