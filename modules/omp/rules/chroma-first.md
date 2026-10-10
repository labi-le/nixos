---
description: Query the chroma code index before grep/glob
condition: '.*'
scope: "tool:grep, tool:glob"
interruptMode: never
---

Code search starts in the index: call the chroma MCP tool `chroma_query_documents`
before `grep` or `glob`.

- Collection: `code-<owner>-<repo>`, taken from the repository's git origin
  remote — lowercased, every character outside `[a-z0-9._-]` becomes `-`, runs
  collapsed, a trailing `.git` dropped: `git@github.com:labi-le/nixos.git` →
  `code-labi-le-nixos`. Without a remote: `code-<basename>-<first 8 hex of
  sha1(cwd)>`. Names over 63 characters carry a `-<hash8>` suffix.
- Never query a `__manifests` collection — those are membership sidecars, not
  content. `chroma_list_collections` resolves the name when the derivation is
  unclear.

grep/glob stay correct for what the index cannot answer: an exact symbol or path
already known, a file the indexer skips, or a repository with no collection.
