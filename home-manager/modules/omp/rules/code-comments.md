---
description: Comments and examples in code
condition: ['(?:^|\n)[^\S\n]*(?://|#)[^\n]*\n[^\S\n]*(?://|#)|/\*(?:[^*]|\*(?!/))*\n', '(?:^|\n)(?:[^\n]*[^\S\n])?(?://|#|--[^\S\n])[^\n]*(?:[\w.%+-]+@[\w-]+\.[A-Za-z][A-Za-z]+|\b\d\d?\d?\.\d\d?\d?\.\d\d?\d?\.\d\d?\d?\b|\b[\w-]+\.(?:internal|intranet|corp|lan|prod|prd|stage|stg)\b|/home/[A-Za-z_][\w.-]*)']
globs: ['*.ts','*.tsx','*.js','*.jsx','*.nix','*.py','*.sh','*.bash','*.zsh','*.go','*.rs','*.c','*.h','*.cpp','*.hpp','*.java','*.kt','*.rb','*.lua','*.sql','*.yaml','*.yml','*.toml']
scope: tool
interruptMode: tool-only
---

A comment is warranted only where the code cannot speak for itself; if
the reader can already see what the line does, delete the comment.
Explain why, never what. A comment running past a line or two is a sign
the code needs a better name or a smaller function — fix the code
instead of narrating it. Rationale that genuinely needs length belongs
in the commit message or under `docs/`. Never leave a scaffolding marker
— `TODO`, `FIXME`, `XXX`, `HACK` — or commented-out code behind: git
remembers what was deleted, and a marker is a promise nobody keeps.
Examples inside comments, docstrings and fixtures stay neutral: real
hostnames, IP addresses, emails, ticket-less internal URLs, absolute
home paths and anything copied out of a production log get replaced by
`foo`, `bar`, `user@example.com`, `192.0.2.1` or `example.com`, and
credentials and tokens are never pasted at all, not even shortened.
`comment-gate.ts` refuses the mechanical cases — markers,
commented-out code, real data, credential shapes — so treat those as
settled and spend the judgement on the rest. Prose files are not code:
a match inside markdown or a document is a false positive, so proceed.
