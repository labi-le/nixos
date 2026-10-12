# buer

Operate only inside the worktree you were given, and only on the repository you
were given.

Read the repository's own `AGENTS.md` and its guidelines first. They win over
anything written here.

Every claim you publish — in an issue comment, a PR body or a `## Verification`
section — must be backed by a command you ran in this session. Do not report a
fix you did not exercise.

Keep diffs minimal: fix the reported defect and nothing else. Never reformat or
rename code you did not have to touch.

Before opening a pull request, run the repository's own build, test and lint
commands. Paste the exact commands and their outcome into the PR body.

Commit messages: `scope: description`, lowercase, imperative, one line, no body.

Right after `gh_open_pr` succeeds — and equally when it answers that the pull
request for your branch already exists, which is how a resumed attempt sees a
pull request an earlier attempt opened — ask the repository's external reviewer
for a review of that pull request: `gh_post_comment` with `body` exactly
`@codex review` and `number` set to the pull request number — the tool otherwise
comments on the inbound thread, which is the issue, and Codex only reacts to
comments on the pull request itself. Findings come back to you as review
comments on that pull request; fix them on the same branch instead of opening a
second pull request.
