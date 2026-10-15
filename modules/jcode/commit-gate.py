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
    started = False
    for ch in text:
        if escaped:
            token += ch
            escaped = False
        elif ch == "\\" and quote != "'":
            escaped = True
            started = True
        elif quote:
            if ch == quote:
                quote = None
            else:
                if ch in ("$", "`") and quote == '"':
                    token += "\0expand"
                token += ch
        elif ch in ("'", '"'):
            quote = ch
            started = True
        elif ch.isspace():
            if started:
                words.append(token)
                token = ""
                started = False
        else:
            if ch in ("$", "`"):
                token += "\0expand"
            token += ch
            started = True
    if started:
        words.append(token)
    return words

def check_mr_title(title):
    if "\0" in title:
        return "MR title must be literal text"
    if not title.strip() or any(ch in title for ch in "\n\r\u2028\u2029"):
        return "MR title must be nonempty and one line"
    if len(title) > 70:
        return "MR title exceeds 70 Unicode characters"
    return None


def check_mr_options(options):
    create = False
    title = False
    description = False
    for option in options:
        if "\0" in option or option.startswith(("$", "`")):
            return "MR push option must be literal text"
        if option == "merge_request.create":
            create = True
        elif option.startswith("merge_request.title="):
            title = True
            broken = check_mr_title(option[len("merge_request.title="):])
            if broken:
                return broken
        elif option.startswith("merge_request.description="):
            description = True
            if option[len("merge_request.description="):] != "":
                return "MR description must be exactly empty"
    if create and (not title or not description):
        return "MR creation requires an explicit literal title and empty description"
    return None


def mr_risk(words):
    git_at = next((i for i, w in enumerate(words) if w == "git" or w.endswith("/git")), -1)
    if git_at >= 0:
        at = git_at + 1
        globals_ = []
        while at < len(words) and words[at].startswith("-"):
            token = words[at]
            at += 1
            if token == "-c":
                if at < len(words):
                    globals_.append(words[at])
                    at += 1
            elif token.startswith("-c") and len(token) > 2:
                globals_.append(token[2:])
            elif token in ("-C", "--git-dir", "--work-tree"):
                at += 1
        if at >= len(words) or words[at] not in ("push", "config"):
            return None
        action = words[at]
        at += 1
        options = [value.split("=", 1)[1] for value in globals_ if re.match(r"^push\.pushOption=", value, re.I)]
        if action == "config":
            for i in range(at, len(words) - 1):
                if words[i].lower() == "push.pushoption":
                    return check_mr_options([words[i + 1]])
            return None
        while at < len(words):
            token = words[at]
            at += 1
            if token in ("-o", "--push-option"):
                if at >= len(words):
                    return "push option has no readable value"
                options.append(words[at])
                at += 1
            elif token.startswith("--push-option="):
                options.append(token[len("--push-option="):])
            elif token.startswith("-o") and len(token) > 2:
                options.append(token[3:] if token[2] == "=" else token[2:])
        return check_mr_options(options)
    cli_at = next((i for i, w in enumerate(words) if re.search(r"(?:^|/)(gh|glab)$", w)), -1)
    if cli_at < 0:
        return None
    cli = words[cli_at].rsplit("/", 1)[-1]
    group_at = cli_at + 1
    while group_at < len(words) and words[group_at].startswith("-"):
        flag = words[group_at]
        group_at += 1
        if flag in ("-R", "--repo", "--hostname", "-h"):
            group_at += 1
    if words[group_at:group_at + 1] != (["pr"] if cli == "gh" else ["mr"]):
        return None
    action = words[group_at + 1] if group_at + 1 < len(words) else ""
    create = action in ("create", "new")
    if not create and action != ("edit" if cli == "gh" else "update"):
        return None
    title = False
    description = False
    at = group_at + 2
    while at < len(words):
        token = words[at]
        at += 1
        if re.match(r"^--(?:fill(?:-first|-verbose|-commit-body)?|template|editor|recover|attach|signoff|web|body-file|description-file|title-file)(?:=|$)", token) or (
            re.match(r"^-[A-Za-z]*[fe][A-Za-z]*$", token)
        ) or (cli == "gh" and re.match(r"^-[FT](?:=|.|$)", token)):
            return "MR text from a file, template, editor or generated source cannot be checked"
        kind = None
        value = None
        if token in ("--title", "-t") or (
            cli == "gh" and token in ("--body", "-b")
        ) or (cli == "glab" and token in ("--description", "-d")):
            kind = "title" if token in ("--title", "-t") else "description"
            if at < len(words):
                value = words[at]
                at += 1
        else:
            long = re.match(r"^--(title|body|description)=(.*)$", token, re.S)
            short = re.match(r"^-([tbd])=?(.*)$", token, re.S)
            if long and long.group(1) in ("title", "body" if cli == "gh" else "description"):
                kind = "title" if long.group(1) == "title" else "description"
                value = long.group(2)
            elif short and short.group(1) in ("t", "b" if cli == "gh" else "d"):
                kind = "title" if short.group(1) == "t" else "description"
                value = short.group(2)
        if kind is None:
            continue
        if kind == "title":
            title = True
        else:
            description = True
        if value is None:
            return "MR text flag has no literal value"
        broken = check_mr_title(value) if kind == "title" else (
            None if value == "" else "MR description must be exactly empty"
        )
        if broken:
            return broken
    if create and (not title or not description):
        return "MR creation requires an explicit literal title and empty description"
    return None


def check_mr(command, depth=0):
    for segment in split_commands(command):
        words = split_shell(segment)
        broken = mr_risk(words)
        if broken:
            fail("commit-gate: " + broken)
        if depth >= 2 or not words or words[0].rsplit("/", 1)[-1] not in WRAPPERS | {"bash", "sh", "zsh"}:
            continue
        for token in words[1:]:
            if re.search(r"\b(?:git|gh|glab)\b", token):
                check_mr(token, depth + 1)




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
    check_mr(command)
    commit = git_commit_command(command)
    if commit:
        check_commit(command)
    allow()


if __name__ == "__main__":
    main()
