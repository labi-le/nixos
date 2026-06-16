#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "chromadb>=1.0.0",
#   "pathspec>=0.12.0",
#   "tree-sitter>=0.22.0",
#   "tree-sitter-php",
#   "tree-sitter-go",
#   "tree-sitter-javascript",
#   "tree-sitter-typescript",
#   "tree-sitter-python",
#   "tree-sitter-rust",
#   "tree-sitter-bash",
#   "watchfiles>=0.22.0",
# ]
# ///
"""
Semantic code indexer for ChromaDB using tree-sitter AST parsing.

Uses tree-sitter to split code at semantic boundaries (functions, methods,
type declarations) so chunks never cut a function in half.  Falls back to
sliding-window line chunking for languages without a grammar.

Backend: systemd chromadb service (NixOS ``services.chromadb``).

Usage:
    ./scripts/index_repo.py                                # index cwd
    ./scripts/index_repo.py /path/to/project               # index given dir
    ./scripts/index_repo.py --collection my-project
    ./scripts/index_repo.py --host 192.168.1.2 --port 8000

Per-project isolation via collection name (default: ``code-<basename>``).
"""
from __future__ import annotations

import argparse
import asyncio
import hashlib
import pathlib
import signal
import sys
from typing import Iterable

import chromadb
import pathspec

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

EXTS: set[str] = {
    ".py", ".pyi",
    ".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs",
    ".php",
    ".go", ".rs", ".java", ".kt", ".swift", ".c", ".h", ".cc", ".cpp", ".hpp",
    ".rb", ".ex", ".exs", ".cs",
    ".nix",
    ".sql",
    ".sh", ".bash", ".zsh",
    ".md", ".mdx", ".rst",
    ".toml", ".yaml", ".yml", ".json", ".jsonc",
    ".vue", ".svelte", ".html", ".css", ".scss",
}

EXTRA_IGNORE: list[str] = [
    ".git/", ".chroma/", ".direnv/", ".venv/", "venv/",
    "node_modules/", "vendor/",
    "dist/", "build/", "out/", "target/", "result",
    ".next/", ".nuxt/", ".cache/", ".parcel-cache/",
    "__pycache__/", "*.pyc",
    "*.min.js", "*.min.css", "*.map",
    "storage/", "bootstrap/cache/",
    "*.lock", "package-lock.json", "composer.lock", "uv.lock",
    "yarn.lock", "pnpm-lock.yaml",
]

CHUNK_LINES = 120
OVERLAP = 20
MAX_FILE_BYTES = 512 * 1024
MAX_SEMANTIC_LINES = 200
BATCH = 2000

# ---------------------------------------------------------------------------
# tree-sitter registry
# ---------------------------------------------------------------------------

# file extension → language key
EXT_TO_LANG: dict[str, str] = {
    ".php": "php",
    ".go": "go",
    ".js": "javascript", ".jsx": "javascript",
    ".mjs": "javascript", ".cjs": "javascript",
    ".ts": "typescript", ".tsx": "tsx",
    ".py": "python", ".pyi": "python",
    ".rs": "rust",
    ".sh": "bash", ".bash": "bash", ".zsh": "bash",
}

# AST node types extracted as individual semantic chunks.
# Walk stops at these — nested functions stay inside the parent chunk.
SEMANTIC_TYPES: dict[str, set[str]] = {
    "php": {"function_definition", "method_declaration"},
    "go": {"function_declaration", "method_declaration", "type_declaration"},
    "javascript": {"function_declaration", "method_definition"},
    "typescript": {
        "function_declaration", "method_definition",
        "type_alias_declaration", "interface_declaration",
    },
    "tsx": {
        "function_declaration", "method_definition",
        "type_alias_declaration", "interface_declaration",
    },
    "python": {"function_definition"},
    "rust": {
        "function_item", "struct_item", "enum_item",
        "trait_item", "macro_definition",
    },
    "bash": {"function_definition"},
}

# Container types whose *name* field is used as scope context for children.
_SCOPE_TYPES: dict[str, set[str]] = {
    "php": {"class_declaration", "interface_declaration",
            "trait_declaration", "enum_declaration"},
    "go": set(),
    "javascript": {"class_declaration"},
    "typescript": {"class_declaration"},
    "tsx": {"class_declaration"},
    "python": {"class_definition"},
    "rust": {"impl_item", "trait_item"},
    "bash": set(),
}

_PARSER_SPECS: dict[str, tuple[str, str]] = {
    "php":        ("tree_sitter_php",        "language_php"),
    "go":         ("tree_sitter_go",         "language"),
    "javascript": ("tree_sitter_javascript", "language"),
    "typescript": ("tree_sitter_typescript", "language_typescript"),
    "tsx":        ("tree_sitter_typescript", "language_tsx"),
    "python":     ("tree_sitter_python",     "language"),
    "rust":       ("tree_sitter_rust",       "language"),
    "bash":       ("tree_sitter_bash",       "language"),
}

_PARSERS: dict = {}                # lang_key → tree_sitter.Parser
_PARSER_FAILED: set[str] = set()   # lang_keys we already tried and failed
_TS_AVAILABLE: bool | None = None  # cached tree_sitter import result


def _get_parser(lang_key: str):
    """Load tree-sitter grammar on first use; cache result.

    Skips eager init of all 8 grammars — only languages actually seen
    in the repo pay the loading cost.
    """
    global _TS_AVAILABLE
    if lang_key in _PARSERS:
        return _PARSERS[lang_key]
    if lang_key in _PARSER_FAILED:
        return None

    if _TS_AVAILABLE is None:
        try:
            import tree_sitter  # noqa: F401
            _TS_AVAILABLE = True
        except ImportError:
            print("  warning: tree-sitter not installed, using line-window only",
                  file=sys.stderr)
            _TS_AVAILABLE = False
    if not _TS_AVAILABLE:
        return None

    spec = _PARSER_SPECS.get(lang_key)
    if spec is None:
        _PARSER_FAILED.add(lang_key)
        return None

    try:
        from tree_sitter import Language, Parser
        mod_name, func_name = spec
        mod = __import__(mod_name)
        fn = getattr(mod, func_name, None) or getattr(mod, "language")
        lang = Language(fn())
        p = Parser()
        p.language = lang
        _PARSERS[lang_key] = p
        return p
    except Exception as exc:
        print(f"  warning: {lang_key} grammar unavailable ({exc})",
              file=sys.stderr)
        _PARSER_FAILED.add(lang_key)
        return None


# ---------------------------------------------------------------------------
# AST helpers
# ---------------------------------------------------------------------------

def _collect_semantic(node, lang_key: str) -> list:
    """Walk AST, collect semantic nodes. Stop descent at each match."""
    targets = SEMANTIC_TYPES.get(lang_key, set())
    results: list = []

    def walk(n):
        if n.type in targets:
            results.append(n)
            return
        for child in n.children:
            walk(child)

    walk(node)
    return results


def _get_scope(node, lang_key: str) -> str:
    """Climb parents to build scope string (e.g. class name)."""
    containers = _SCOPE_TYPES.get(lang_key, set())
    parts: list[str] = []
    parent = node.parent
    while parent:
        if parent.type in containers:
            name_node = parent.child_by_field_name("name")
            if name_node:
                parts.append(name_node.text.decode("utf-8", errors="replace"))
            elif parent.type == "impl_item":
                type_node = parent.child_by_field_name("type")
                if type_node:
                    parts.append(type_node.text.decode("utf-8", errors="replace"))
        parent = parent.parent
    return ".".join(reversed(parts))


# ---------------------------------------------------------------------------
# Chunking
# ---------------------------------------------------------------------------

# (start_line 1-indexed, body, node_type, scope)
Chunk = tuple[int, str, str, str]


def _line_window(text: str) -> Iterable[tuple[int, str]]:
    """Sliding-window line chunking.  Yields (1-based offset, body)."""
    lines = text.splitlines()
    if not lines:
        return
    step = max(1, CHUNK_LINES - OVERLAP)
    for i in range(0, len(lines), step):
        body = "\n".join(lines[i : i + CHUNK_LINES])
        if body.strip():
            yield i + 1, body
        if i + CHUNK_LINES >= len(lines):
            break


def _ts_chunk(text: str, lang_key: str) -> list[Chunk]:
    """Tree-sitter semantic chunking.  Returns [] when unavailable."""
    parser = _get_parser(lang_key)
    if parser is None:
        return []

    try:
        tree = parser.parse(text.encode("utf-8"))
    except Exception:
        return []

    nodes = _collect_semantic(tree.root_node, lang_key)
    if not nodes:
        return []

    nodes.sort(key=lambda n: n.start_byte)
    lines = text.split("\n")
    total = len(lines)
    results: list[Chunk] = []
    cursor = 0  # next uncovered 0-indexed line

    for node in nodes:
        node_start = node.start_point[0]
        node_end = node.end_point[0]
        # end_point col==0 means the node doesn't occupy that line
        if node.end_point[1] == 0 and node_end > node_start:
            node_end -= 1

        # gap before this node → line-window
        if cursor < node_start:
            gap = "\n".join(lines[cursor:node_start])
            if gap.strip():
                for off, body in _line_window(gap):
                    results.append((cursor + off, body, "preamble", ""))

        # the semantic node itself
        chunk_text = node.text.decode("utf-8", errors="replace")
        scope = _get_scope(node, lang_key)
        start_line = node_start + 1

        if len(chunk_text.splitlines()) > MAX_SEMANTIC_LINES:
            for off, body in _line_window(chunk_text):
                results.append((start_line + off - 1, body, node.type, scope))
        else:
            results.append((start_line, chunk_text, node.type, scope))

        cursor = max(cursor, node_end + 1)

    # trailing gap
    if cursor < total:
        gap = "\n".join(lines[cursor:])
        if gap.strip():
            for off, body in _line_window(gap):
                results.append((cursor + off, body, "preamble", ""))

    return results


def _detect_lang(path: pathlib.Path) -> str | None:
    """Map file path to tree-sitter language key."""
    if path.name.endswith(".blade.php"):
        return None  # Blade templates are too mixed for PHP grammar
    return EXT_TO_LANG.get(path.suffix.lower())


def chunk_file(text: str, path: pathlib.Path) -> Iterable[Chunk]:
    """Chunk file contents — tree-sitter first, line-window fallback."""
    lang_key = _detect_lang(path)
    if lang_key:
        ts_chunks = _ts_chunk(text, lang_key)
        if ts_chunks:
            yield from ts_chunks
            return
    for line_no, body in _line_window(text):
        yield line_no, body, "window", ""


# ---------------------------------------------------------------------------
# File iteration & gitignore
# ---------------------------------------------------------------------------

def load_ignore(root: pathlib.Path) -> pathspec.PathSpec:
    patterns: list[str] = list(EXTRA_IGNORE)
    gi = root / ".gitignore"
    if gi.exists():
        patterns += gi.read_text(encoding="utf-8", errors="ignore").splitlines()
    return pathspec.PathSpec.from_lines("gitwildmatch", patterns)


def iter_files(root: pathlib.Path, spec: pathspec.PathSpec) -> Iterable[pathlib.Path]:
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix.lower() not in EXTS and path.name not in {
            "Makefile", "Dockerfile", "Justfile", ".envrc",
        }:
            continue
        rel = path.relative_to(root).as_posix()
        if spec.match_file(rel):
            continue
        try:
            if path.stat().st_size > MAX_FILE_BYTES:
                continue
        except OSError:
            continue
        yield path


# ---------------------------------------------------------------------------
# Batch upsert
# ---------------------------------------------------------------------------

def flush(col, ids, docs, metas) -> int:
    if not ids:
        return 0
    col.add(ids=ids, documents=docs, metadatas=metas)
    return len(ids)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Per-file chunk computation (shared by one-shot and daemon delta)
# ---------------------------------------------------------------------------

def _chunks_for_file(
    path: pathlib.Path,
    root: pathlib.Path,
) -> tuple[str, list[tuple[str, str, dict]], int, int, bool]:
    """Compute every (id, body, meta) for ``path``.

    Returns ``(rel, chunks, ts_count, win_count, ok)``.
    ``ok`` is False when the file is binary (UnicodeDecodeError); chunks is
    empty when the file is unreadable or vanished mid-read.
    """
    rel = path.relative_to(root).as_posix()
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return rel, [], 0, 0, False
    except OSError:
        return rel, [], 0, 0, True

    lang = path.suffix.lstrip(".").lower() or path.name
    chunks: list[tuple[str, str, dict]] = []
    ts = win = 0

    for line_no, body, node_type, scope in chunk_file(text, path):
        cid = hashlib.sha1(
            f"{rel}:{line_no}:{body}".encode("utf-8"),
        ).hexdigest()
        meta: dict = {
            "path": rel, "line": line_no, "lang": lang, "type": node_type,
        }
        if scope:
            meta["scope"] = scope
        chunks.append((cid, body, meta))
        if node_type == "window":
            win += 1
        else:
            ts += 1

    return rel, chunks, ts, win, True


# ---------------------------------------------------------------------------
# One-shot incremental scan (CLI default + daemon's initial sync)
# ---------------------------------------------------------------------------

def one_shot_index(
    col,
    root: pathlib.Path,
    spec: pathspec.PathSpec,
) -> dict:
    """Walk ``root``, diff collection's existing IDs vs current chunks, add
    new, delete stale. Returns a stats dict.
    """
    try:
        existing: set[str] = set(col.get(include=[])["ids"])
    except Exception as e:
        print(f"  warning: failed to fetch existing ids ({e}); treating as empty",
              file=sys.stderr)
        existing = set()

    seen: set[str] = set()
    ids: list[str] = []
    docs: list[str] = []
    metas: list[dict] = []
    added = unchanged = files = ts_chunks = win_chunks = skipped_bin = 0

    for path in iter_files(root, spec):
        _rel, chunks, ts, win, ok = _chunks_for_file(path, root)
        if not ok:
            skipped_bin += 1
            continue
        files += 1
        ts_chunks += ts
        win_chunks += win

        for cid, body, meta in chunks:
            seen.add(cid)
            if cid in existing:
                unchanged += 1
                continue
            ids.append(cid)
            docs.append(body)
            metas.append(meta)
            if len(ids) >= BATCH:
                added += flush(col, ids, docs, metas)
                ids, docs, metas = [], [], []

    added += flush(col, ids, docs, metas)

    stale = list(existing - seen)
    deleted = 0
    for i in range(0, len(stale), BATCH):
        batch_ids = stale[i:i + BATCH]
        col.delete(ids=batch_ids)
        deleted += len(batch_ids)

    return {
        "files": files,
        "added": added,
        "unchanged": unchanged,
        "deleted": deleted,
        "ts_chunks": ts_chunks,
        "win_chunks": win_chunks,
        "skipped_bin": skipped_bin,
    }


# ---------------------------------------------------------------------------
# Daemon: inotify-driven live indexing via watchfiles (notify-rs backend)
# ---------------------------------------------------------------------------
#
# Launched by the opencode wrapper (home-manager/modules/opencode/wrappers.nix)
# as ``index-repo --daemon <project>`` and killed when opencode exits. There is
# no status socket: the wrapper only starts and stops it, nothing queries it.

def _safe(call, *args, **kwargs):
    """Run a chromadb call; log + swallow failures so the watch loop survives
    a transient backend hiccup instead of dying.
    """
    try:
        return call(*args, **kwargs)
    except Exception as e:
        print(f"daemon: chromadb call failed ({e})", file=sys.stderr)
        return None


def _build_path_to_ids(col) -> dict[str, set[str]]:
    """Reconstruct ``path -> {chunk ids}`` from the collection's metadata.

    The daemon needs this to know which chunks to retire when a file changes
    or is deleted. Built from ChromaDB itself (not the scan) so it reflects
    the collection's actual state and survives across daemon restarts.
    """
    mapping: dict[str, set[str]] = {}
    try:
        got = col.get(include=["metadatas"])
    except Exception as e:
        print(f"daemon: failed to load existing metadata ({e})", file=sys.stderr)
        return mapping
    ids = got.get("ids") or []
    metas = got.get("metadatas") or []
    for cid, meta in zip(ids, metas):
        path = (meta or {}).get("path")
        if path:
            mapping.setdefault(path, set()).add(cid)
    return mapping


async def _process_changes(col, root, changes, path_to_ids, all_ids) -> None:
    """Apply one debounced batch of file-system events as a per-file delta."""
    from watchfiles import Change

    actions: dict[str, str] = {}
    paths: dict[str, pathlib.Path] = {}
    for change, path_str in changes:
        p = pathlib.Path(path_str)
        try:
            rel = p.relative_to(root).as_posix()
        except ValueError:
            continue
        paths[rel] = p
        if change == Change.deleted:
            actions[rel] = "delete"
        elif actions.get(rel) != "delete":
            actions[rel] = "upsert"

    added = deleted = 0
    for rel, action in actions.items():
        path = paths[rel]

        if action == "delete" or not path.exists():
            old = path_to_ids.pop(rel, set())
            if old:
                await asyncio.to_thread(_safe, col.delete, ids=list(old))
                all_ids -= old
                deleted += len(old)
            continue

        _, chunks, _, _, ok = _chunks_for_file(path, root)
        if not ok:
            continue  # binary file slipped past the filter

        seen: set[str] = set()
        new_ids: list[str] = []
        new_docs: list[str] = []
        new_metas: list[dict] = []
        for cid, body, meta in chunks:
            seen.add(cid)
            if cid in all_ids:
                continue
            new_ids.append(cid)
            new_docs.append(body)
            new_metas.append(meta)

        stale = list(path_to_ids.get(rel, set()) - seen)
        if stale:
            await asyncio.to_thread(_safe, col.delete, ids=stale)
            all_ids -= set(stale)
            deleted += len(stale)

        if new_ids:
            await asyncio.to_thread(
                _safe, col.add,
                ids=new_ids, documents=new_docs, metadatas=new_metas,
            )
            all_ids |= set(new_ids)
            added += len(new_ids)

        path_to_ids[rel] = seen

    if added or deleted:
        print(
            f"daemon: live update — added={added} deleted={deleted} "
            f"chunks={len(all_ids)}",
            file=sys.stderr,
        )


def _make_watch_filter(root: pathlib.Path, spec: pathspec.PathSpec):
    """watchfiles filter mirroring ``iter_files`` (gitignore + extensions)."""
    from watchfiles import BaseFilter

    extra = {"Makefile", "Dockerfile", "Justfile", ".envrc"}

    class _F(BaseFilter):
        def __call__(self, change, path_str: str) -> bool:
            p = pathlib.Path(path_str)
            try:
                rel = p.relative_to(root).as_posix()
            except ValueError:
                return False
            if spec.match_file(rel):
                return False
            if p.suffix.lower() not in EXTS and p.name not in extra:
                return False
            return True

    return _F()


async def daemon_main(args, col, root: pathlib.Path, spec) -> int:
    from watchfiles import awatch

    print(f"daemon: initial sync of {root}", file=sys.stderr)
    stats = await asyncio.to_thread(one_shot_index, col, root, spec)
    path_to_ids = await asyncio.to_thread(_build_path_to_ids, col)
    all_ids: set[str] = set()
    for chunk_ids in path_to_ids.values():
        all_ids |= chunk_ids

    grammars = ", ".join(sorted(_PARSERS)) if _PARSERS else "none"
    print(
        f"daemon: initial sync done — files={stats['files']} "
        f"added={stats['added']} unchanged={stats['unchanged']} "
        f"deleted={stats['deleted']} chunks={len(all_ids)} grammars={grammars}",
        file=sys.stderr,
    )

    stop_event = asyncio.Event()
    loop = asyncio.get_running_loop()

    def _shutdown(*_):
        stop_event.set()

    for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        try:
            loop.add_signal_handler(sig, _shutdown)
        except (NotImplementedError, RuntimeError):
            signal.signal(sig, lambda *_: _shutdown())

    watch_filter = _make_watch_filter(root, spec)
    print(
        f"daemon: watching {root} (debounce={args.debounce}ms)",
        file=sys.stderr,
    )

    try:
        async for changes in awatch(
            root,
            debounce=args.debounce,
            step=50,
            recursive=True,
            watch_filter=watch_filter,
            stop_event=stop_event,
        ):
            await _process_changes(col, root, changes, path_to_ids, all_ids)
    except asyncio.CancelledError:
        pass
    except Exception as e:
        print(f"daemon: watch loop crashed ({e})", file=sys.stderr)
        return 4

    print("daemon: stopped", file=sys.stderr)
    return 0


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument("path", nargs="?", default=".", help="project directory")
    p.add_argument("--host", default="192.168.1.2")
    p.add_argument("--port", type=int, default=8000)
    p.add_argument("--collection", default=None,
                   help="collection name (default: code-<basename>)")
    p.add_argument("--ssl", action="store_true", help="use https")
    p.add_argument("--full-rebuild", action="store_true",
                   help="drop the collection and re-embed everything "
                        "(default: incremental — only changed chunks are embedded)")
    p.add_argument("--daemon", action="store_true",
                   help="run as a long-lived indexer: initial sync, then "
                        "live-update the collection on file changes (inotify). "
                        "Launched and reaped by the opencode wrapper.")
    p.add_argument("--debounce", type=int, default=800,
                   help="daemon: debounce window in ms for batching fs events "
                        "(default: 800)")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    root = pathlib.Path(args.path).resolve()
    if not root.is_dir():
        print(f"error: {root} is not a directory", file=sys.stderr)
        return 2

    collection_name = args.collection or f"code-{root.name}"
    mode_str = (
        "daemon" if args.daemon
        else ("full rebuild" if args.full_rebuild else "incremental")
    )

    print(
        f"indexing {root} → {args.host}:{args.port}  "
        f"collection={collection_name} mode={mode_str}",
        file=sys.stderr,
    )

    try:
        client = chromadb.HttpClient(host=args.host, port=args.port, ssl=args.ssl)
        client.heartbeat()
    except Exception as e:
        print(
            f"error: cannot reach chromadb at {args.host}:{args.port} ({e})\n"
            "is `systemctl status chromadb` running?",
            file=sys.stderr,
        )
        return 3

    spec = load_ignore(root)

    if args.full_rebuild:
        try:
            client.delete_collection(collection_name)
        except Exception:
            pass

    col = client.get_or_create_collection(
        collection_name,
        metadata={"hnsw:space": "cosine"},
    )

    if args.daemon:
        return asyncio.run(daemon_main(args, col, root, spec))

    stats = one_shot_index(col, root, spec)
    grammars = ", ".join(sorted(_PARSERS)) if _PARSERS else "none"
    print(
        f"done. files={stats['files']} added={stats['added']} "
        f"unchanged={stats['unchanged']} deleted={stats['deleted']} "
        f"(tree-sitter={stats['ts_chunks']}, window={stats['win_chunks']}) "
        f"skipped_binary={stats['skipped_bin']} grammars={grammars} "
        f"collection={collection_name} count={col.count()}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
