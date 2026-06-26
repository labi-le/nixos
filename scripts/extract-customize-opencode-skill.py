#!/usr/bin/env python3
"""Regenerate home-manager/modules/opencode/skills/customize-opencode/SKILL.md.

`customize-opencode` is opencode's only built-in skill, but it ships embedded in
the compiled (bun-bundled) opencode binary as a JS template literal at the
logical path /builtin/customize-opencode.md -- there is no upstream repo to pin
via scripts/update-skills.sh. This script slices that literal back out so the
vendored folder-skill can be refreshed after an opencode upgrade.

Usage:
    scripts/extract-customize-opencode-skill.py        # auto-detect `opencode`
    OPENCODE_BIN=/path/to/binary scripts/extract-customize-opencode-skill.py

It is version-independent: it anchors on a unique marker inside the skill body
rather than a fixed byte offset, then applies full JS string-escape decoding
(bun ASCII-escapes non-ASCII, e.g. em-dash -> \\u2014).
"""
import glob
import os
import re
import shutil
import subprocess
import sys

MARKER = b"Built-in skill. Name and description are registered"

HERE = os.path.dirname(os.path.realpath(__file__))
OUT_DIR = os.path.normpath(
    os.path.join(HERE, "..", "home-manager/modules/opencode/skills/customize-opencode")
)
OUT = os.path.join(OUT_DIR, "SKILL.md")

DESC = (
    "Use ONLY when the user is editing or creating opencode's own configuration: "
    "opencode.json, opencode.jsonc, files under .opencode/, or files under "
    "~/.config/opencode/. Also use when creating or fixing opencode agents, "
    "subagents, commands, skills, plugins, MCP servers, or permission rules. Do "
    "not use for the user's own application code, or for any project that is not "
    "configuring opencode itself."
)


def _running_version():
    try:
        out = subprocess.run(
            ["opencode", "--version"], capture_output=True, text=True, timeout=30
        )
    except Exception:
        return None
    m = re.search(r"\d+\.\d+\.\d+", (out.stdout or "") + (out.stderr or ""))
    return m.group(0) if m else None


def candidate_bins():
    env = os.environ.get("OPENCODE_BIN")
    if env:
        return [env]
    cands = []
    # The real ~160MB ELF lives at /nix/store/*-opencode-<version>/bin/.opencode-wrapped;
    # the launcher on PATH is a tiny wrapper that doesn't carry the embedded skill.
    version = _running_version()
    if version:
        cands += sorted(glob.glob(f"/nix/store/*-opencode-{version}/bin/.opencode-wrapped"))
    exe = shutil.which("opencode")
    if exe:
        real = os.path.realpath(exe)
        cands.append(os.path.join(os.path.dirname(real), ".opencode-wrapped"))
        cands.append(real)
    if not cands:
        sys.exit("opencode not found; set OPENCODE_BIN=/path/to/opencode binary")
    seen = set()
    return [c for c in cands if not (c in seen or seen.add(c))]


def load_binary():
    for b in candidate_bins():
        if os.path.isfile(b):
            blob = open(b, "rb").read()
            if MARKER in blob:
                return b, blob
    sys.exit("embedded skill marker not found; set OPENCODE_BIN to the right binary")


def unescaped_backtick(buf, pos):
    if buf[pos] != 0x60:
        return False
    k = pos - 1
    bs = 0
    while k >= 0 and buf[k] == 0x5C:
        bs += 1
        k -= 1
    return bs % 2 == 0


HEX = "0123456789abcdefABCDEF"
SIMPLE = {
    "n": "\n", "r": "\r", "t": "\t", "b": "\b", "f": "\f", "v": "\v",
    "0": "\0", "`": "`", "$": "$", "\\": "\\", "'": "'", '"': '"', "/": "/",
}


def decode_js(s):
    out = []
    n = len(s)
    p = 0
    while p < n:
        c = s[p]
        if c != "\\":
            out.append(c)
            p += 1
            continue
        if p + 1 >= n:
            out.append("\\")
            p += 1
            continue
        nx = s[p + 1]
        if nx == "u":
            if p + 2 < n and s[p + 2] == "{":
                e = s.find("}", p + 3)
                if e != -1:
                    try:
                        out.append(chr(int(s[p + 3:e], 16)))
                        p = e + 1
                        continue
                    except ValueError:
                        pass
            h = s[p + 2:p + 6]
            if len(h) == 4 and all(ch in HEX for ch in h):
                out.append(chr(int(h, 16)))
                p += 6
                continue
        elif nx == "x":
            h = s[p + 2:p + 4]
            if len(h) == 2 and all(ch in HEX for ch in h):
                out.append(chr(int(h, 16)))
                p += 4
                continue
        elif nx == "\n":  # line continuation
            p += 2
            continue
        out.append(SIMPLE.get(nx, nx))
        p += 2
    return "".join(out)


def main():
    binary, data = load_binary()
    i = data.find(MARKER)
    if data.find(MARKER, i + 1) != -1:
        sys.exit("marker is not unique - aborting to avoid wrong slice")

    start = next((j + 1 for j in range(i, 0, -1) if unescaped_backtick(data, j)), None)
    if start is None:
        sys.exit("opening backtick not found")
    end = next((j for j in range(start, len(data)) if unescaped_backtick(data, j)), None)
    if end is None:
        sys.exit("closing backtick not found")

    body = decode_js(data[start:end].decode("utf-8", "replace"))
    try:
        body = body.encode("utf-16", "surrogatepass").decode("utf-16")
    except Exception:
        pass
    body = body.lstrip("\n")

    leftover = re.findall(r"\\u[0-9a-fA-F]{4}|\\x[0-9a-fA-F]{2}", body)
    if leftover:
        sys.exit("leftover escapes after decode: %s" % leftover[:10])

    os.makedirs(OUT_DIR, exist_ok=True)
    safe_desc = DESC.replace("\\", "\\\\").replace('"', '\\"')
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("---\nname: customize-opencode\n")
        f.write('description: "%s"\n---\n\n' % safe_desc)
        f.write(body)
        if not body.endswith("\n"):
            f.write("\n")

    print("source : %s" % binary)
    print("wrote  : %s (%d body chars)" % (OUT, len(body)))


if __name__ == "__main__":
    main()
