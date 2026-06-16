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
import hashlib
import pathlib
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
BATCH = 256

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

_PARSERS: dict = {}  # lang_key → tree_sitter.Parser


def _init_parsers() -> None:
    """Load available tree-sitter grammars; skip gracefully on failure."""
    try:
        from tree_sitter import Language, Parser  # noqa: F811
    except ImportError:
        print("  warning: tree-sitter not installed, using line-window only",
              file=sys.stderr)
        return

    specs: list[tuple[str, str, str]] = [
        ("php",        "tree_sitter_php",        "language_php"),
        ("go",         "tree_sitter_go",         "language"),
        ("javascript", "tree_sitter_javascript", "language"),
        ("typescript", "tree_sitter_typescript", "language_typescript"),
        ("tsx",        "tree_sitter_typescript", "language_tsx"),
        ("python",     "tree_sitter_python",     "language"),
        ("rust",       "tree_sitter_rust",       "language"),
        ("bash",       "tree_sitter_bash",       "language"),
    ]

    for key, mod_name, func_name in specs:
        try:
            mod = __import__(mod_name)
            fn = getattr(mod, func_name, None) or getattr(mod, "language")
            lang = Language(fn())
            p = Parser()
            p.language = lang
            _PARSERS[key] = p
        except Exception as exc:
            print(f"  warning: {key} grammar unavailable ({exc})",
                  file=sys.stderr)


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
    parser = _PARSERS.get(lang_key)
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
    return p.parse_args()


def main() -> int:
    args = parse_args()
    root = pathlib.Path(args.path).resolve()
    if not root.is_dir():
        print(f"error: {root} is not a directory", file=sys.stderr)
        return 2

    collection_name = args.collection or f"code-{root.name}"

    print(f"indexing {root} → {args.host}:{args.port}"
          f"  collection={collection_name}", file=sys.stderr)

    print("loading tree-sitter grammars…", file=sys.stderr)
    _init_parsers()
    if _PARSERS:
        print(f"  active: {', '.join(sorted(_PARSERS))}", file=sys.stderr)
    else:
        print("  none available — using line-window only", file=sys.stderr)

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

    # Full rebuild each run.
    try:
        client.delete_collection(collection_name)
    except Exception:
        pass
    col = client.create_collection(
        collection_name,
        metadata={"hnsw:space": "cosine"},
    )

    ids: list[str] = []
    docs: list[str] = []
    metas: list[dict] = []
    total = 0
    files = 0
    ts_chunks = 0
    win_chunks = 0
    skipped_bin = 0

    for path in iter_files(root, spec):
        rel = path.relative_to(root).as_posix()
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            skipped_bin += 1
            continue
        files += 1
        lang = path.suffix.lstrip(".").lower() or path.name

        for line_no, body, node_type, scope in chunk_file(text, path):
            cid = hashlib.sha1(
                f"{rel}:{line_no}:{body}".encode("utf-8"),
            ).hexdigest()
            ids.append(cid)
            docs.append(body)
            meta: dict = {
                "path": rel, "line": line_no, "lang": lang, "type": node_type,
            }
            if scope:
                meta["scope"] = scope
            metas.append(meta)

            if node_type == "window":
                win_chunks += 1
            else:
                ts_chunks += 1

            if len(ids) >= BATCH:
                total += flush(col, ids, docs, metas)
                ids, docs, metas = [], [], []

    total += flush(col, ids, docs, metas)
    print(
        f"done. files={files} chunks={total} "
        f"(tree-sitter={ts_chunks}, window={win_chunks}) "
        f"skipped_binary={skipped_bin} "
        f"collection={collection_name} count={col.count()}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
