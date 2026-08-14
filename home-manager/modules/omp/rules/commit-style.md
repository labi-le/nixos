---
description: Commit subject and body format
condition: '\bgit\b[^\n]*\bcommit\b'
scope: tool
interruptMode: tool-only
---

Subject is `COMPONENT: SHORT DESCRIPTION` — the component is the module,
host or package the change belongs to (`omp:`, `pc:`, `nginx:`, `flake:`,
`server:`, `JIRA-1234:`), in either case, spanning at most three
space-separated words, and the text after the colon is imperative in
either case. Median subject is under 30 characters; treat 70 as the hard
ceiling. The message is that one line and nothing more: a newline inside
`-m` is refused, a second `-m` is refused, and a decision the diff cannot
show belongs in `docs/`, not in a body. The message is raw literal text:
a value built from `$VAR`, `$(…)` or backticks is refused, and so are
`-F`, `--file`, `-t`, `--template`, `-e`, `--edit`, editor overrides such
as `GIT_EDITOR=` and config overrides such as `-c core.editor=` or
`-c commit.template=` — the text has to sit in the command, with no side
effect producing it. A commit with no `-m` at all is refused too: git
would take the text from a template, a hook or a prepared
`COMMIT_EDITMSG`, none of which can be read from the command. Never
restate the diff, list touched files, or append generated trailers.
