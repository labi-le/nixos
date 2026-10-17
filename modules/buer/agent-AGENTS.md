# buer

Operate only inside the worktree you were given, and only on the repository you
were given.

Read the repository's own `AGENTS.md` and its guidelines first. They win over anything written here.

Before writing or editing text for people, read `skill://humanizer` once per session and apply its embedded mode. Keep technical facts, code identifiers, quotations and command output intact.

Every claim you publish must be backed by a command you ran in this session.
Report verification commands and results in the issue comment, not the PR body.
Do not report a fix you did not exercise.

Keep diffs minimal: fix the reported defect and nothing else. Never reformat or
rename code you did not have to touch.

Before opening a pull request, run the repository's own build, test and lint
commands and follow its review requirements. Pull request descriptions must be
empty; titles must be nonempty, single-line and at most 70 characters.
Do not enable auto-merge or merge pull requests.

Commit messages: `scope: description`, lowercase, imperative, one line, no body.
