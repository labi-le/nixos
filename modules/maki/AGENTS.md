# Scope

Only sections marked (top-level) bind the user-facing session. Subagents
follow their briefs, complete them, and yield; no supervising other agents or
starting review/fix loops unless explicitly requested in the brief.

# Operating principle (top-level)

Work directly by default; delegation is an optimization, not required. Do not
spawn a subagent if direct work is faster and clearer: brief-writing, waiting
and validation costs must be justified by the work moved out of the parent
session. The top-level agent may inspect and edit files, run commands, and
verify directly.

# Human-facing prose (top-level)

Before writing text for people, read the `humanizer` skill once per session
and apply it to every chat reply, review comment, issue, merge request
description and documentation change. Draft and audit internally, then publish
only the final wording. Keep technical facts, code identifiers, quotations and
required project language intact. Prefer plain, natural phrasing over review
templates and formulaic headings.

# Delegation (top-level)

Delegate only for clear benefit:

- `research`: non-trivial discovery when relevant code or ownership is
  genuinely unclear, especially across directories or subsystems.
- `general`: bounded implementation that saves meaningful parent effort or can
  proceed independently.

Agent availability alone is no reason to delegate. Prefer direct work for
small edits, obvious fixes, localized changes, documentation, configuration
tweaks, straightforward tests, and simple searches. Prefer one worker; fan out
only when tasks are genuinely independent and parallelism materially helps.

Every delegated brief states the goal, relevant files or search area,
constraints, acceptance criteria, and the relevant verification. Workers do
not commit unless asked.

# Verification (top-level)

Understand enough context to determine scope and risk, then run the smallest
check that gives useful confidence: targeted tests, type checking, linting,
build checks, or direct inspection. Avoid expensive broad checks when the
change cannot reasonably affect them. Stop once the requested behavior is
implemented and verification passes.

# Chroma search

When the `chroma` MCP server is available, prefer it for code discovery and
semantic search. Use `rg` or `grep` when the exact symbol, string, or path is
already known. Verify Chroma results against the source before editing.

# Commit style

Before any `git commit`, `git push`, `gh pr create`, or `glab mr create`, read
the `commit-style` skill.

# Project naming

Before proposing a name for a new project, repository, binary, service or
host, read the `project-naming` skill.

# Code comments

Before writing or editing code, read the `code-comments` skill.
