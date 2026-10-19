---
name: commit-style
description: Commit messages and merge request text
---

The subject is `COMPONENT: SHORT DESCRIPTION`. The component is the module,
host or package the change belongs to (`omp:`, `pc:`, `nginx:`, `flake:`,
`server:`, `JIRA-1234:`), spanning at most three space-separated words. The
text after the colon is imperative. The median subject is under 30 characters;
treat 70 as the hard ceiling.

The message is that one line and nothing more. A newline inside `-m` is
refused, a second `-m` is refused, and a decision the diff cannot show belongs
in `docs/`, not in a body. The message is raw literal text: a value built from
`$VAR`, `$(…)` or backticks is refused, and so are `-F`, `--file`, `-t`,
`--template`, `-e`, `--edit`, editor overrides such as `GIT_EDITOR=` and
config overrides such as `-c core.editor=` or `-c commit.template=`. A commit
with no `-m` at all is refused too.

MR and PR descriptions must be exactly empty. Titles must be nonempty, one
line and at most 70 Unicode characters. Creation requires a literal title and
an explicit empty description: `--body ''` for `gh`, `--description ''` for
`glab`, or `-o merge_request.description=` for `git push`, together with
`-o 'merge_request.title=short title'`. Never generate this text from commit
history, files, templates, editors, recovery data or shell expansions.
Metadata-only edits remain allowed.

Do not commit unless the user requests it or the surrounding workflow
explicitly requires it.
