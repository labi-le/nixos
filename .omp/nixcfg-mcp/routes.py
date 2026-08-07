import fnmatch
import re
from pathlib import Path

from config import DELIMITER_RE, HOSTS, PATH_CELL_RE, PATH_SHAPE_RE, REPO, ROUTES, STOP_WORDS
from protocol import ToolError
from shell import envelope


ROUTES_CACHE = {"mtime": None, "sections": None, "rows": None, "idf": None}


def split_row(line):
    cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
    return cells


def section_hosts(heading, cell_text):
    lowered = heading.lower()
    if lowered.startswith("pc-specific"):
        return ["pc"]
    if lowered.startswith("fx516-specific"):
        return ["fx516"]
    if lowered.startswith("notebook-specific"):
        return ["notebook"]
    if lowered.startswith("server-specific"):
        return ["server"]
    if lowered.startswith("home manager") or lowered.startswith("desktop-only"):
        found = [host for host in HOSTS if host != "server" and host in cell_text]
        return found or ["pc", "fx516", "notebook"]
    return list(HOSTS)


def extract_paths(cell):
    paths = []
    for token in PATH_CELL_RE.findall(cell or ""):
        token = token.strip()
        if not (PATH_SHAPE_RE.match(token) or token == "Makefile"):
            continue
        entry = {"path": token}
        if "<" in token:
            entry["placeholder"] = True
        if "*" in token:
            entry["glob"] = True
        if token.startswith(("~", "/")):
            entry["outside_repo"] = True
        if "/" not in token and token != "Makefile":
            entry["bare_name"] = True
        unresolvable = entry.get("placeholder") or entry.get("glob") or entry.get("outside_repo")
        entry["exists"] = None if unresolvable else (REPO / token).exists()
        paths.append(entry)
    return paths


def parse_routes():
    mtime = ROUTES.stat().st_mtime
    if ROUTES_CACHE["mtime"] == mtime:
        return ROUTES_CACHE
    lines = ROUTES.read_text().splitlines()
    sections = []
    current = None
    index = 0
    while index < len(lines):
        line = lines[index]
        if line.startswith("## "):
            heading = line[3:].strip()
            scope = PATH_CELL_RE.search(heading)
            current = {
                "heading": re.sub(r"\s*\(.*\)\s*$", "", heading),
                "raw_heading": heading,
                "line": index + 1,
                "scope": scope.group(1) if scope else None,
                "columns": [],
                "rows": [],
                "prose": [],
            }
            sections.append(current)
            index += 1
            continue
        if (
            current is not None
            and line.startswith("|")
            and index + 1 < len(lines)
            and DELIMITER_RE.match(lines[index + 1].strip())
        ):
            headers = split_row(line)
            current["columns"] = headers
            index += 2
            while index < len(lines) and lines[index].startswith("|"):
                current["rows"].append(
                    {"line": index + 1, "cells": split_row(lines[index]), "columns": headers}
                )
                index += 1
            continue
        if current is not None and line.strip() and not line.startswith("#"):
            current["prose"].append(line.strip())
        index += 1

    rows = []
    for section in sections:
        for raw in section["rows"]:
            record = build_record(section, raw)
            if record is not None:
                rows.append(record)
    ROUTES_CACHE.update(
        {"mtime": mtime, "sections": sections, "rows": rows, "idf": build_idf(rows)}
    )
    return ROUTES_CACHE


def build_record(section, raw):
    columns = raw["columns"]
    cells = raw["cells"]
    named = {}
    surplus = []
    for position, cell in enumerate(cells):
        if position < len(columns):
            named[columns[position]] = cell
        elif cell:
            surplus.append(cell)
    concern = next(
        (named[key] for key in ("Task / Concern", "Task", "Concern") if named.get(key)), None
    )
    file_cell = named.get("File")
    steps = [named[key] for key in columns if key.startswith("Step") and named.get(key)]
    if concern is None and named.get("Purpose"):
        concern = named["Purpose"]
    if concern is None:
        return None
    notes = [named[key] for key in ("Notes", "Active Hosts", "What") if named.get(key)] + surplus
    paths = extract_paths(file_cell or "")
    for step in steps:
        paths.extend(extract_paths(step))
    if not paths:
        return None
    text = " ".join([concern] + notes + [file_cell or ""] + steps)
    return {
        "section": section["heading"],
        "section_scope": section["scope"],
        "line": raw["line"],
        "concern": concern,
        "paths": paths,
        "steps": steps,
        "notes": "; ".join(notes),
        "hosts": section_hosts(section["heading"], text),
        "tokens": tokenize(concern),
        "note_tokens": tokenize("; ".join(notes)),
        "path_tokens": tokenize(" ".join(entry["path"] for entry in paths)),
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
    for word in re.split(r"[^a-z0-9]+", (text or "").lower()):
        if len(word) > 2 and word not in STOP_WORDS:
            tokens |= variants(word)
    return tokens


def build_idf(rows):
    import math

    total = max(1, len(rows))
    counts = {}
    for row in rows:
        for token in row["tokens"] | row["note_tokens"] | row["path_tokens"]:
            counts[token] = counts.get(token, 0) + 1
    return {token: math.log(1 + total / (1 + count)) for token, count in counts.items()}


def score_row(row, query_tokens, raw_query, idf):
    weight = lambda tokens, factor: factor * sum(idf.get(token, 1.0) for token in query_tokens & tokens)
    score = weight(row["tokens"], 1.0) + weight(row["note_tokens"], 0.4) + weight(row["path_tokens"], 0.6)
    if raw_query and raw_query in row["concern"].lower():
        score += 2.0
    for entry in row["paths"]:
        if Path(entry["path"]).stem.lower() in query_tokens:
            score += 1.0
            break
    if row["section"].startswith("Optional"):
        score -= 1.5
    return score


def tool_route(args, request_id, token):
    query = (args.get("query") or "").strip()
    if not query:
        raise ToolError("query is required")
    host = args.get("host")
    if host is not None and host not in HOSTS:
        raise ToolError(f"unknown host {host!r}; expected one of {', '.join(HOSTS)}")
    limit = max(1, min(int(args.get("limit") or 5), 25))
    cache = parse_routes()
    query_tokens = tokenize(query)
    scored = []
    for row in cache["rows"]:
        if host is not None and host not in row["hosts"]:
            continue
        score = score_row(row, query_tokens, query.lower(), cache["idf"])
        if score > 0:
            scored.append((score, row))
    scored.sort(key=lambda pair: (-pair[0], pair[1]["line"]))
    matches = []
    for score, row in scored[:limit]:
        match = {
            "score": round(score, 2),
            "section": row["section"],
            "section_scope": row["section_scope"],
            "routes_line": row["line"],
            "concern": row["concern"],
            "paths": row["paths"],
            "hosts": row["hosts"],
        }
        if row["notes"]:
            match["notes"] = row["notes"]
        if row["steps"]:
            match["steps"] = row["steps"]
        matches.append(match)
    header = {
        "query": query,
        "source": "docs/routes.md",
        "confident": bool(matches) and matches[0]["score"] >= 1.0,
        "matches": matches,
    }
    if not header["confident"]:
        header["fallback"] = (
            "not routed: search with glob/grep, then add the row to docs/routes.md "
            "per the nix-routing skill"
        )
    return envelope(header), False


def tool_route_file(args, request_id, token):
    target = (args.get("path") or "").strip()
    if target.startswith("./"):
        target = target[2:]
    if not target:
        raise ToolError("path is required")
    cache = parse_routes()
    entries = []
    loose = []
    for row in cache["rows"]:
        for entry in row["paths"]:
            candidate = entry["path"]
            record = {
                "section": row["section"],
                "routes_line": row["line"],
                "concern": row["concern"],
                "matched_path": candidate,
                "notes": row["notes"],
                "hosts": row["hosts"],
            }
            if candidate == target or (entry.get("glob") and fnmatch.fnmatch(target, candidate)):
                entries.append(record)
                break
            if Path(candidate).name == Path(target).name:
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
        header["suggested_section"] = suggest_section(target)
        header["action"] = "add a row to docs/routes.md per the nix-routing skill"
        if loose:
            header["same_basename_elsewhere"] = loose[:10]
    return envelope(header), False


def suggest_section(target):
    if target.startswith("home-manager/modules/"):
        return "Home Manager Modules"
    if target.startswith("hosts/"):
        return "PC-Specific Modules"
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
            found.update(
                str(path.relative_to(REPO)) for path in root.rglob("*.nix")
            )
    found.update(str(path.relative_to(REPO)) for path in REPO.glob("*.nix"))
    return found


def tool_routes_audit(args, request_id, token):
    cache = parse_routes()
    wanted = args.get("section")
    sections = []
    for section in cache["sections"]:
        summary = {
            "heading": section["heading"],
            "line": section["line"],
            "scope": section["scope"],
            "columns": section["columns"],
            "rows": len(section["rows"]),
        }
        if section["prose"]:
            summary["prose"] = " ".join(section["prose"])
        sections.append(summary)
    header = {"file": "docs/routes.md", "sections": sections}
    if wanted:
        picked = [
            row
            for row in cache["rows"]
            if row["section"].lower().startswith(wanted.lower())
        ]
        if not picked:
            raise ToolError(
                f"no section matching {wanted!r}; headings: "
                + ", ".join(item["heading"] for item in sections)
            )
        header["section"] = wanted
        header["rows"] = [
            {
                "routes_line": row["line"],
                "concern": row["concern"],
                "paths": row["paths"],
                "notes": row["notes"],
                "hosts": row["hosts"],
            }
            for row in picked
        ]
    if args.get("validate", True):
        dead = []
        routed = set()
        for row in cache["rows"]:
            for entry in row["paths"]:
                routed.add(entry["path"])
                if entry["exists"] is False and not entry.get("bare_name"):
                    dead.append(
                        {
                            "routes_line": row["line"],
                            "section": row["section"],
                            "concern": row["concern"],
                            "path": entry["path"],
                        }
                    )
        globs = [entry for entry in routed if "*" in entry]
        unrouted = sorted(
            path
            for path in repo_nix_files()
            if path not in routed
            and not any(fnmatch.fnmatch(path, pattern) for pattern in globs)
        )
        header["dead_paths"] = dead
        header["unrouted_nix_files"] = unrouted
    return envelope(header), False
