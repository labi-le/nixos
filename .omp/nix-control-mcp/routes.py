import fnmatch
import json
import re
import tomllib
from pathlib import Path

from config import (
    HOSTS,
    MAX_TEXT,
    PATH_SHAPE_RE,
    REGISTRY,
    REPO,
    ROUTES,
    ROUTES_NOTES,
    STOP_WORDS,
)
from protocol import ToolError
from text import envelope


CACHE = {"mtime": None, "rows": None, "idf": None}


ALIASES = {
    "терминал": "terminal",
    "терминалы": "terminal",
    "свап": "swap",
    "подкачка": "swap",
    "загрузчик": "boot",
    "загрузка": "boot",
    "монитор": "monitor",
    "мониторы": "monitor",
    "мониторинг": "monitoring",
    "диск": "disk",
    "диски": "disk",
    "сеть": "network",
    "сети": "network",
    "секрет": "secret",
    "секреты": "secret",
    "уведомление": "notification",
    "уведомления": "notification",
    "шрифт": "font",
    "шрифты": "font",
    "тема": "theme",
    "темы": "theme",
    "звук": "audio",
    "пакет": "package",
    "пакеты": "package",
    "служба": "service",
    "сервис": "service",
    "сервисы": "service",
    "логи": "log",
    "журнал": "journal",
    "клавиши": "keybindings",
    "клавиатура": "keyboard",
    "сборка": "build",
    "пересборка": "rebuild",
    "почта": "mail",
    "зеркало": "mirror",
    "кэш": "cache",
    "резервная": "backup",
    "бэкап": "backup",
    "роутер": "router",
    "прошивка": "firmware",
}


def variants(word):
    forms = {word}
    if len(word) > 3 and word.endswith("es"):
        forms.add(word[:-2])
    if len(word) > 3 and word.endswith("s"):
        forms.add(word[:-1])
    return forms


def tokenize(text):
    tokens = set()
    for word in re.findall(r"[^\W_]+", (text or "").casefold()):
        if len(word) <= 2 or word in STOP_WORDS:
            continue
        tokens |= variants(word)
        alias = ALIASES.get(word)
        if alias:
            tokens |= variants(alias)
    return tokens


def route_paths(entry):
    paths = []
    for token in entry.get("paths") or []:
        token = str(token).strip()
        if not (PATH_SHAPE_RE.match(token) or token == "Makefile"):
            continue
        record = {"path": token}
        if "<" in token:
            record["placeholder"] = True
        if "*" in token:
            record["glob"] = True
        if token.startswith(("~", "/")):
            record["outside_repo"] = True
        if "/" not in token and token != "Makefile":
            record["bare_name"] = True
        unresolvable = record.get("placeholder") or record.get("glob") or record.get("outside_repo")
        record["exists"] = None if unresolvable else (REPO / token).exists()
        paths.append(record)
    return paths


def note_sections():
    sections = {}
    if not ROUTES_NOTES.exists():
        return sections
    anchor = None
    body = []
    for line in ROUTES_NOTES.read_text().splitlines():
        if line.startswith("## "):
            if anchor:
                sections[anchor] = "\n".join(body).strip()
            anchor = line[3:].strip()
            body = []
        elif anchor:
            body.append(line)
    if anchor:
        sections[anchor] = "\n".join(body).strip()
    return sections


def build_row(number, group, entry, sections):
    task = " ".join(str(entry.get("task") or "").split())
    if not task:
        return None
    paths = route_paths(entry)
    if not paths:
        return None
    hosts = [host for host in entry.get("hosts") or [] if host in HOSTS]
    aliases = [str(alias) for alias in entry.get("aliases") or []]
    note = str(entry.get("note") or "")
    doc = str(entry.get("doc") or "")
    steps = [str(step) for step in entry.get("steps") or []]
    anchor = doc.partition("#")[2] if doc.startswith("docs/routes-notes.md#") else ""
    knowledge = sections.get(anchor, "") if anchor else ""
    return {
        "number": number,
        "group": group,
        "task": task,
        "paths": paths,
        "hosts": hosts or list(HOSTS),
        "note": note,
        "doc": doc,
        "steps": steps,
        "task_tokens": tokenize(task),
        "alias_tokens": tokenize(" ".join(aliases)),
        "group_tokens": tokenize(group),
        "note_tokens": tokenize(note + " " + " ".join(steps) + " " + knowledge),
        "path_tokens": tokenize(" ".join(item["path"] for item in paths)),
        "doc_tokens": tokenize(anchor.replace("-", " ")),
    }


def parse_registry():
    mtime = REGISTRY.stat().st_mtime
    notes_mtime = ROUTES_NOTES.stat().st_mtime if ROUTES_NOTES.exists() else None
    if CACHE["mtime"] == (mtime, notes_mtime):
        return CACHE
    data = tomllib.loads(REGISTRY.read_text())
    sections = note_sections()
    rows = []
    for number, entry in enumerate(data.get("route") or [], start=1):
        row = build_row(number, str(entry.get("group") or "Ungrouped"), entry, sections)
        if row is not None:
            rows.append(row)
    CACHE.update({"mtime": (mtime, notes_mtime), "rows": rows, "idf": build_idf(rows)})
    return CACHE


def build_idf(rows):
    import math

    total = max(1, len(rows))
    counts = {}
    for row in rows:
        for token in (
            row["task_tokens"]
            | row["alias_tokens"]
            | row["note_tokens"]
            | row["path_tokens"]
            | row["doc_tokens"]
        ):
            counts[token] = counts.get(token, 0) + 1
    return {token: math.log(1 + total / (1 + count)) for token, count in counts.items()}


def score_row(row, query_tokens, raw_query, idf):
    def weight(tokens, factor):
        return factor * sum(idf.get(token, 1.0) for token in query_tokens & tokens)

    score = (
        weight(row["task_tokens"], 1.0)
        + weight(row["alias_tokens"], 1.0)
        + weight(row["path_tokens"], 0.6)
        + weight(row["group_tokens"], 0.3)
        + weight(row["note_tokens"], 0.3)
        + weight(row["doc_tokens"], 0.2)
    )
    if raw_query and raw_query in row["task"].lower():
        score += 2.0
    for entry in row["paths"]:
        if Path(entry["path"]).stem.lower() in query_tokens:
            score += 1.0
            break
    return score


def evidence(row, query_tokens, raw_query):
    reasons = []
    if raw_query and raw_query in row["task"].lower():
        reasons.append("task substring")
    for field, label in (
        ("task_tokens", "task"),
        ("alias_tokens", "alias"),
        ("path_tokens", "path"),
        ("group_tokens", "group"),
        ("note_tokens", "note"),
        ("doc_tokens", "doc"),
    ):
        for token in sorted(query_tokens & row[field])[:4]:
            reasons.append(label + ":" + token)
    return reasons


def clip(text, limit):
    return text if len(text) <= limit else text[: limit - 1] + "~"


def clip_strings(value, limit):
    if isinstance(value, str):
        return clip(value, limit)
    if isinstance(value, list):
        return [clip_strings(item, limit) for item in value]
    if isinstance(value, dict):
        return {key: clip_strings(item, limit) for key, item in value.items()}
    return value


def fit_response(header, key):
    def size():
        return len(json.dumps(header, indent=2, ensure_ascii=False))

    if size() <= MAX_TEXT:
        return header
    for limit in (500, 240, 120):
        settled = clip_strings(header, limit)
        header.clear()
        header.update(settled)
        if size() <= MAX_TEXT:
            header["truncated_fields"] = True
            return header
    trimmed = {
        name: [
            {field: value for field, value in item.items() if field not in ("note", "steps", "prose")}
            for item in items
        ]
        if isinstance(items, list) and all(isinstance(item, dict) for item in items)
        else items
        for name, items in header.items()
    }
    header.clear()
    header.update(trimmed)
    if size() <= MAX_TEXT:
        header["truncated_fields"] = True
        return header
    items = header.get(key) or []
    while len(items) > 1 and size() > MAX_TEXT:
        items.pop()
        header["omitted_matches"] = header.get("omitted_matches", 0) + 1
    for name in ("dead_paths", "unrouted_nix_files", "duplicate_paths", "missing_docs"):
        values = header.get(name)
        while isinstance(values, list) and len(values) > 1 and size() > MAX_TEXT:
            values.pop()
            header[name + "_omitted"] = header.get(name + "_omitted", 0) + 1
    header["truncated"] = True
    return header


def present(row):
    match = {
        "group": row["group"],
        "task": row["task"],
        "paths": row["paths"],
        "hosts": row["hosts"],
    }
    if row["note"]:
        match["note"] = row["note"]
    if row["doc"]:
        match["doc"] = row["doc"]
    if row["steps"]:
        match["steps"] = row["steps"]
    return match


def tool_route(args, request_id, token):
    query = (args.get("query") or "").strip()
    if not query:
        raise ToolError("query is required")
    host = args.get("host")
    if host is not None and host not in HOSTS:
        raise ToolError(f"unknown host {host!r}; expected one of {', '.join(HOSTS)}")
    limit = max(1, min(int(args.get("limit") or 5), 25))
    cache = parse_registry()
    query_tokens = tokenize(query)
    scored = []
    for row in cache["rows"]:
        if host is not None and host not in row["hosts"]:
            continue
        score = score_row(row, query_tokens, query.lower(), cache["idf"])
        if score > 0:
            scored.append((score, row))
    scored.sort(key=lambda pair: (-pair[0], pair[1]["number"]))
    matches = []
    for score, row in scored[:limit]:
        match = present(row)
        match["score"] = round(score, 2)
        match["evidence"] = evidence(row, query_tokens, query.lower())
        matches.append(match)
    confident = False
    settled = []
    if matches and matches[0]["score"] >= 1.0:
        settled = [reason for reason in matches[0]["evidence"] if reason.split(":")[0] not in ("note", "doc")]
        confident = bool(settled)
    header = {
        "query": query,
        "source": "docs/routes.toml",
        "confident": confident,
        "matches": matches,
    }
    if matches and not settled:
        header["caveat"] = (
            "only note or doc text matched, so the path is a guess; confirm it before editing"
        )
    if not confident:
        header["fallback"] = (
            "no confident route: verify with route_file or a targeted search before editing, "
            "then add a [[route]] entry to docs/routes.toml"
        )
    return envelope(fit_response(header, "matches")), False


def tool_route_file(args, request_id, token):
    target = (args.get("path") or "").strip()
    if target.startswith("./"):
        target = target[2:]
    if not target:
        raise ToolError("path is required")
    cache = parse_registry()
    entries = []
    loose = []
    for row in cache["rows"]:
        for entry in row["paths"]:
            candidate = entry["path"]
            if candidate == target or (entry.get("glob") and fnmatch.fnmatch(target, candidate)):
                record = present(row)
                record["matched_path"] = candidate
                entries.append(record)
                break
            if Path(candidate).name == Path(target).name:
                record = present(row)
                record["matched_path"] = candidate
                record["match"] = "basename only"
                loose.append(record)
                break
    header = {
        "path": target,
        "exists": (REPO / target).exists(),
        "routed": bool(entries),
        "entries": entries,
    }
    if not entries:
        header["suggested_group"] = suggest_group(target)
        header["action"] = "add a [[route]] entry to docs/routes.toml"
        if loose:
            header["same_basename_elsewhere"] = loose[:10]
    return envelope(fit_response(header, "entries")), False


def suggest_group(target):
    if target.startswith("home-manager/modules/"):
        return "Home Manager Modules"
    if target.startswith("hosts/"):
        return "Host-Specific Modules"
    if target.startswith("pkgs/"):
        return "Cross-Cutting Tasks"
    if target.startswith("modules/"):
        return "System Modules"
    return "Other Files"


def repo_nix_files():
    found = set()
    for base in ("modules", "hosts", "home-manager", "pkgs"):
        root = REPO / base
        if root.exists():
            found.update(str(path.relative_to(REPO)) for path in root.rglob("*.nix"))
    found.update(str(path.relative_to(REPO)) for path in REPO.glob("*.nix"))
    return found


def doc_targets():
    anchors = set()
    if ROUTES_NOTES.exists():
        anchors.update(
            "docs/routes-notes.md#" + line[3:].strip()
            for line in ROUTES_NOTES.read_text().splitlines()
            if line.startswith("## ")
        )
    return anchors


def covered_by_directory(path, routed):
    parent = Path(path).parent
    roots = [str(parent)] + [str(ancestor) for ancestor in parent.parents]
    return any(str(Path(owner).parent) == root and Path(owner).name in ("default.nix", "flake.nix") for root in roots for owner in routed)


def coverage_patterns(routed):
    patterns = []
    for path in routed:
        if "*" in path or "<" in path:
            patterns.append(path.replace("<", "*").replace(">", ""))
    return patterns


def host_closures():
    closures = {}
    for host in HOSTS:
        config = REPO / "hosts" / ("configuration.nix" if host == "pc" else f"configuration-{host}.nix")
        seen = set()
        queue = [config.resolve()] if config.exists() else []
        while queue:
            current = queue.pop()
            if current in seen:
                continue
            seen.add(current)
            try:
                text = current.read_text()
            except (OSError, UnicodeDecodeError):
                continue
            for token in re.findall(r"[\"'](\.{1,2}/[\w./-]+)[\"']", text):
                target = (current.parent / token).resolve()
                if target.is_dir():
                    for name in ("default.nix", "flake.nix"):
                        if (target / name).exists():
                            queue.append((target / name).resolve())
                            break
                elif target.suffix == ".nix" and target.exists():
                    queue.append(target)
        closures[host] = {str(path.relative_to(REPO)) for path in seen if REPO in path.parents}
    return closures


def host_drift(rows):
    closures = host_closures()
    drifted = []
    for row in rows:
        if row["steps"]:
            continue
        actual = set()
        for entry in row["paths"]:
            path = entry["path"]
            if path.startswith(("~", "/")) or "*" in path or "<" in path:
                continue
            candidate = REPO / path
            for host, files in closures.items():
                if path in files:
                    actual.add(host)
                elif not candidate.suffix and f"{path}/default.nix" in files:
                    actual.add(host)
        if actual and actual != set(row["hosts"]):
            drifted.append(
                {
                    "task": row["task"],
                    "declared": row["hosts"],
                    "imported_by": [host for host in HOSTS if host in actual],
                }
            )
    return drifted


def tool_routes_audit(args, request_id, token):
    cache = parse_registry()
    group = args.get("group") or args.get("section")
    groups = {}
    for row in cache["rows"]:
        groups[row["group"]] = groups.get(row["group"], 0) + 1
    header = {
        "file": "docs/routes.toml",
        "groups": groups,
        "routes": len(cache["rows"]),
    }
    if group:
        picked = [row for row in cache["rows"] if row["group"].lower().startswith(group.lower())]
        if not picked:
            raise ToolError(
                f"no group matching {group!r}; groups: " + ", ".join(sorted(groups))
            )
        header["group"] = group
        header["rows"] = [present(row) for row in picked]
    if args.get("validate", True):
        dead = []
        owners = {}
        docs = []
        routed = set()
        known = doc_targets()
        for row in cache["rows"]:
            for entry in row["paths"]:
                routed.add(entry["path"])
                if not row["steps"]:
                    owners.setdefault(entry["path"], []).append(row["task"])
                if entry["exists"] is False and not entry.get("bare_name"):
                    dead.append(
                        {
                            "task": row["task"],
                            "group": row["group"],
                            "path": entry["path"],
                        }
                    )
            if row["doc"] and row["doc"].startswith("docs/routes-notes.md#"):
                if row["doc"] not in known:
                    docs.append({"task": row["task"], "doc": row["doc"]})
        duplicates = [
            {"path": path, "tasks": tasks}
            for path, tasks in sorted(owners.items())
            if len(tasks) > 1
        ]
        globs = [path for path in routed if "*" in path] + coverage_patterns(routed)
        unrouted = sorted(
            path
            for path in repo_nix_files()
            if path not in routed
            and not any(fnmatch.fnmatch(path, pattern) for pattern in globs)
            and not covered_by_directory(path, routed)
        )
        header["dead_paths"] = dead
        header["duplicate_paths"] = duplicates
        header["missing_docs"] = docs
        header["unrouted_nix_files"] = unrouted
        header["host_scope_drift"] = host_drift(cache["rows"])
        header["index_stale"] = not ROUTES.exists() or ROUTES.read_text() != render_index()
    return envelope(fit_response(header, "rows")), False


def render_index():
    cache = parse_registry()
    lines = [
        "# Config routes",
        "",
        "`docs/routes.toml` is the routing registry the `nix-control` route tool reads.",
        "Edit that file, not this index; regenerate this page with",
        "`python3 .omp/nix-control-mcp/routes.py --index`.",
        "",
        "Use `route` for a task in plain language, `route_file` for a path, and",
        "`routes_audit` to check dead paths, duplicate owners and unrouted modules.",
        "Longer knowledge for a route lives in `docs/routes-notes.md`, linked by its `doc`",
        "field. Current values belong in the modules; incident history belongs in the",
        "per-service documents under `docs/`.",
        "",
        "## Host legend",
        "",
        "| Host | Desktop | Home Manager |",
        "| --- | --- | --- |",
        "| pc | yes | yes |",
        "| fx516 | yes | yes |",
        "| notebook | yes | yes |",
        "| server | no | no |",
        "",
        "## Route index",
        "",
        "| Group | Task | Paths | Hosts | Notes |",
        "| --- | --- | --- | --- | --- |",
    ]
    for row in cache["rows"]:
        paths = ", ".join("`" + entry["path"] + "`" for entry in row["paths"])
        hosts = ", ".join(row["hosts"])
        note = row["doc"] or (row["note"] if len(row["note"]) <= 120 else "")
        cells = [row["group"], row["task"], paths, hosts, note]
        lines.append("| " + " | ".join(cell.replace("|", "\\|") for cell in cells) + " |")
    return "\n".join(lines) + "\n"


def write_index():
    ROUTES.write_text(render_index())


if __name__ == "__main__":
    import sys

    if "--index" in sys.argv:
        write_index()
        print("wrote", ROUTES)
