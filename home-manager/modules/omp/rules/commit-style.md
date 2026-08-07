---
description: Commit subject and body format
condition: '\bgit\b[^\n]*\bcommit\b'
scope: tool
interruptMode: tool-only
---

Subject is `component: what changed` — the component is the module, host
or package the change belongs to (`omp:`, `pc:`, `nginx:`, `flake:`,
`server:`), lowercase and imperative after the colon. Median subject is
under 30 characters; treat 70 as the hard ceiling. Add a body only when
the change hides a decision the diff cannot show, and keep it to a couple
of lines. Never restate the diff, list touched files, or append generated
trailers.
