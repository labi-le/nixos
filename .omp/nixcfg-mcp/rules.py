from config import (
    CONDITION_KEYS,
    DEDUP_THRESHOLD,
    FRONTMATTER_ITEM_RE,
    FRONTMATTER_KEY_RE,
    OMP_RULES,
    REGEX_META_RE,
    REPO,
    TRIVIAL_LINE,
)
from protocol import ToolError
from text import envelope


def camel_key(key):
    head, *rest = key.split("-")
    return head + "".join(part[:1].upper() + part[1:] for part in rest)


def strip_quotes(value):
    text = value.strip()
    if len(text) > 1 and text[0] == text[-1] and text[0] in "\"'":
        return text[1:-1]
    return text


def as_sequence(value):
    if isinstance(value, list):
        return [item for item in value if item]
    text = value.strip()
    if text.startswith("[") and text.endswith("]"):
        items = (strip_quotes(part) for part in text[1:-1].split(","))
        return [item for item in items if item]
    text = strip_quotes(text)
    return [text] if text else []


def parse_frontmatter(text):
    if not text.startswith("---"):
        return {}, text, "absent"
    rest = text[3:]
    end = rest.find("\n---")
    if end < 0:
        return {}, text, "unterminated"
    body = rest[end + 4:]
    cut = body.find("\n")
    body = body[cut + 1:] if cut >= 0 else ""
    lines = rest[:end].splitlines()
    fields = {}
    index = 0
    while index < len(lines):
        match = FRONTMATTER_KEY_RE.match(lines[index])
        index += 1
        if match is None:
            continue
        key = camel_key(match.group(1))
        value = match.group(2)
        if value.strip():
            fields[key] = value
            continue
        items = []
        while index < len(lines):
            item = FRONTMATTER_ITEM_RE.match(lines[index])
            if item is None:
                break
            items.append(strip_quotes(item.group(1)))
            index += 1
        fields[key] = items
    return fields, body, "parsed"


def rule_metadata(fields):
    description = fields.get("description")
    always = fields.get("alwaysApply")
    interrupt = fields.get("interruptMode")
    condition = []
    for key in CONDITION_KEYS:
        raw = fields.get(key)
        if raw:
            condition = as_sequence(raw)
            break
    return {
        "description": strip_quotes(description) or None if isinstance(description, str) else None,
        "alwaysApply": isinstance(always, str) and strip_quotes(always) == "true",
        "condition": condition,
        "astCondition": as_sequence(fields.get("astCondition") or ""),
        "globs": as_sequence(fields.get("globs") or ""),
        "scope": as_sequence(fields.get("scope") or ""),
        "interruptMode": strip_quotes(interrupt) if isinstance(interrupt, str) else None,
    }


def resolve_bucket(meta):
    if meta["condition"] or meta["astCondition"]:
        return "ttsr"
    if meta["alwaysApply"]:
        return "always-apply"
    if meta["description"]:
        return "rulebook"
    return "unreachable"


def glob_like(value):
    return "*" in value and REGEX_META_RE.search(value) is None


def normalized_lines(text):
    return [" ".join(line.split()).lower() for line in text.splitlines()]


def significant_lines(text):
    return {line for line in normalized_lines(text) if len(line) > TRIVIAL_LINE}


def overlap_share(body, reference):
    lines = [line for line in normalized_lines(body) if len(line) > TRIVIAL_LINE]
    if not lines:
        return 0
    shared = sum(1 for line in lines if line in reference)
    return int(round(100.0 * shared / len(lines)))


def rule_warnings(record, meta, body, reference):
    found = []
    if record["frontmatter"] == "unterminated":
        found.append(
            "frontmatter opened with --- but never closed: the whole file is read as body "
            "with empty metadata"
        )
    if record["role"] != "rule":
        return found
    if record["bucket"] == "unreachable":
        found.append(
            "no condition/astCondition, not alwaysApply, no description: the rule loads but is "
            "invisible to the system prompt and not resolvable via rule://%s" % record["name"]
        )
    for value in meta["condition"]:
        if glob_like(value):
            found.append(
                "condition %r looks like a file glob: it is silently rewritten to "
                "tool:edit(%s)/tool:write(%s) scope with catch-all condition .*" % (value, value, value)
            )
    if meta["alwaysApply"] and meta["description"]:
        found.append(
            "alwaysApply together with description: the rule lands in always-apply only and is "
            "dropped from the rulebook listing"
        )
    if record["bucket"] == "always-apply" and reference:
        share = overlap_share(body, reference)
        if share >= DEDUP_THRESHOLD:
            found.append(
                "heuristic: %d%% of this body's non-trivial lines also occur in AGENTS.md; "
                "always-apply bodies are deduplicated against loaded context files, so the "
                "injection is silently skipped" % share
            )
    return found


def rule_paths():
    entries = [("RULES", OMP_RULES / "RULES.md"), ("AGENTS", OMP_RULES / "AGENTS.md")]
    directory = OMP_RULES / "rules"
    if directory.is_dir():
        entries.extend((path.stem, path) for path in sorted(directory.glob("*.md")))
    return entries


def tool_rules(args, request_id, token):
    wanted = (args.get("name") or "").strip()
    validate = args.get("validate", True)
    entries = rule_paths()
    missing = [str(path.relative_to(REPO)) for _, path in entries[:2] if not path.is_file()]
    directory = OMP_RULES / "rules"
    if not directory.is_dir():
        missing.append(str(directory.relative_to(REPO)))
    agents = OMP_RULES / "AGENTS.md"
    reference = significant_lines(agents.read_text("utf-8", "replace")) if agents.is_file() else set()
    records = []
    bodies = {}
    for name, path in entries:
        if not path.is_file():
            continue
        fields, body, frontmatter = parse_frontmatter(path.read_text("utf-8", "replace"))
        meta = rule_metadata(fields)
        notes = []
        if name == "RULES":
            meta["alwaysApply"] = True
            notes.append(
                "top-level RULES.md is synthesized as rule name RULES with alwaysApply forced "
                "true regardless of its frontmatter"
            )
        if name == "AGENTS":
            meta["alwaysApply"] = True
            notes.append(
                "AGENTS.md is loaded as a context file, not a rule: always in the prompt, not "
                "addressable via rule://, and the dedup reference for always-apply rule bodies"
            )
        record = {
            "name": name,
            "path": str(path.relative_to(REPO)),
            "role": "context-file" if name == "AGENTS" else "rule",
        }
        record.update(meta)
        record["bucket"] = resolve_bucket(meta)
        record["frontmatter"] = frontmatter
        record["body_lines"] = len(body.strip().splitlines())
        if notes:
            record["notes"] = notes
        if validate:
            found = rule_warnings(record, meta, body, set() if name == "AGENTS" else reference)
            if found:
                record["warnings"] = found
        records.append(record)
        bodies[name] = body.strip()
    buckets = {}
    discovered = len(records)
    for record in records:
        buckets[record["bucket"]] = buckets.get(record["bucket"], 0) + 1
    if wanted:
        picked = [record for record in records if record["name"] == wanted]
        if not picked:
            raise ToolError(
                f"no rule named {wanted!r}; available: "
                + (", ".join(record["name"] for record in records) or "none")
            )
        records = picked
    header = {
        "dir": str(OMP_RULES.relative_to(REPO)),
        "parser": "line-based frontmatter, not full YAML",
        "count": discovered,
        "buckets": buckets,
        "rules": records,
    }
    if missing:
        header["missing"] = missing
    return envelope(header, bodies[wanted] if wanted else ""), False
