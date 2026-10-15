---
description: Commit messages and merge request text
condition: '\b(?:git\b[^\n]*\b(?:commit|push)\b|gh\b[^\n]*\bpr\b|glab\b[^\n]*\bmr\b)'
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

MR and PR descriptions must be exactly empty. Titles must be nonempty,
one line and at most 70 Unicode characters. Creation requires a literal
title and an explicit empty description: `--body ''` for `gh`,
`--description ''` for `glab`, or `-o merge_request.description=` for
`git push`, together with `-o 'merge_request.title=short title'`.
Do not generate this text from commit history, files, templates, editors,
recovery data or shell expansions. Metadata-only edits remain allowed.
The command gate checks these CLI paths, not arbitrary HTTP requests or
push options already inherited from Git configuration.
