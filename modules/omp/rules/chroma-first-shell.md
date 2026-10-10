---
description: Query the chroma code index before shell rg/grep/find
condition: '\b(?:rg|grep|egrep|fgrep|ag|ack|find)\b'
scope: "tool:bash"
interruptMode: never
---

A shell search (`rg`, `grep`, `find`, …) follows the same policy as the `grep`
tool: call the chroma MCP `chroma_query_documents` first, collection
`code-<owner>-<repo>` from the repository's git origin remote. Derivation of the
name and the exceptions where a search is still right: `rule://chroma-first`.
