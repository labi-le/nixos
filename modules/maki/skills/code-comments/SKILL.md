---
name: code-comments
description: Comments and examples in code
---

A comment is warranted only where the code cannot speak for itself; if the
reader can already see what the line does, delete the comment. Explain why,
never what. A comment running past a line or two is a sign the code needs a
better name or a smaller function; fix the code instead of narrating it.
Rationale that genuinely needs length belongs in the commit message or under
`docs/`.

Never leave a scaffolding marker — `TODO`, `FIXME`, `XXX`, `HACK` — or
commented-out code behind: git remembers what was deleted, and a marker is a
promise nobody keeps.

Examples inside comments, docstrings and fixtures stay neutral: real
hostnames, IP addresses, emails, ticket-less internal URLs, absolute home
paths and anything copied out of a production log get replaced by `foo`,
`bar`, `user@example.com`, `192.0.2.1` or `example.com`. Credentials and
tokens are never pasted at all, not even shortened.

Prose files are not code: a match inside Markdown or a document is a false
positive.
