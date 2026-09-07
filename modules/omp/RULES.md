Read `skill://caveman` and answer in that mode for every response.

# Subagent supervision

You supervise running subagents; never park behind a batch.

- `hub jobs` reports only what settled. It carries no liveness signal:
  never diff snapshots to judge health.
- Liveness is `history://`. One bare listing gives every agent's status
  and last-activity age; that is the probe, and it costs the agents
  nothing.
- Judge by last-activity age, never elapsed runtime. Builds and wide
  searches are legitimately silent for many minutes.
- Stale past ~15 minutes: read that agent's `history://<id>` first. Only
  if the transcript is frozen, `hub send` for a one-line status; never
  interrogate one you have not read.
- Still frozen on the next probe: `hub cancel` and re-dispatch narrower.
- `completed` is a claim, not proof. Verify the files actually changed.

# Code comments

NEVER add comments unless they document a non-obvious public API or
explain genuinely non-obvious logic. NEVER add comments that restate
what the code does, repeat the field or function name, describe obvious
error handling, or act as section separators. When in doubt, don't
comment.

# Task workflow

A tracker-keyed task MUST run this loop, in this order, before
yielding:

1. **Implement** — the change itself, plus whatever verification the
   project mandates (tests, linters, type checker).
2. **Review** — a separate pass over the actual diff, dispatched as its
   own `task` (agent `reviewer`), judged against the project's own rule
   sources. Reading your own diff by taste is not a review.
3. **Fix** — address every finding. A finding may be rejected only with
   an explicit justification stated to the user; carry the rejected
   list into the next review so it does not resurface.
4. **Repeat 2→3 until the review comes back empty.** Each iteration is
   a fresh review of the updated diff, never a re-read of the previous
   report. Zero findings — beyond the justifiably rejected ones — is
   the only exit condition.
5. **Log the time** (below). A task with no worklog entry is not
   delivered.

# Jira worklog

When a task is finished and this session has the `jira_worklog` MCP
server, log the time before yielding — MUST, not on request. Call
`worklog_add` with the issue key the current branch is named after,
`started` set to the session's creation date, and `timeSpentSeconds`
set to one hour per commit this session made on that branch —
`3600 × commit count`, nothing else. No commits, no worklog entry.
Session creation is the UTC timestamp in the name of the newest
`.jsonl` under `~/.omp/agent/sessions/<cwd-slug>/`; convert it to the
`+0300` day before using it as `started`.
