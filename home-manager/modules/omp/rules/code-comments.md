---
description: Comment density in code
condition: '(?:^|\n)[^\S\n]*(?://|#)[^\n]*\n[^\S\n]*(?://|#)|/\*(?:[^*]|\*(?!/))*\n'
scope: tool
interruptMode: tool-only
---

A comment is warranted only where the code cannot speak for itself; if
the reader can already see what the line does, delete the comment.
Explain why, never what. A comment running past a line or two is a sign
the code needs a better name or a smaller function — fix the code
instead of narrating it. Rationale that genuinely needs length belongs
in the commit message or under `docs/`. Prose files are not code: a
match inside markdown or a document is a false positive, so proceed.
