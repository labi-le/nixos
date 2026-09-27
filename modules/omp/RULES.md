Read `skill://caveman` ultra mode and answer in that mode for every response.

# Subagent supervision

These rules apply only while subagents are actually running.

- `hub jobs` reports settled jobs; do not use snapshot differences as a
  liveness signal.
- Use `history://` to inspect status and last-activity age.
- Judge liveness by last activity, not total runtime. Builds and broad
  searches may legitimately remain silent for several minutes.
- If an agent is stale for roughly 15 minutes, read its history first.
  Send a status probe only when its transcript appears frozen.
- If it remains frozen on the next probe, cancel it and redispatch a
  narrower task.
- A worker reporting `completed` is not proof. Verify its result before
  relying on it.
- Do not supervise, probe, or spawn agents when the current task does not
  require delegation.

# Task workflow

Follow `AGENTS.md` for execution, delegation, verification, and review.

A tracker-keyed task does not by itself require delegation or independent
review. Do not create a reviewer merely because an issue key or tracker
task exists.

When relevant verification passes and the requested behavior is complete,
finish the task. Do not start additional review/fix cycles without a
concrete reason defined by `AGENTS.md`.

# Jira worklog

When a task is finished and this session has the `jira_worklog` MCP
server, log time before yielding.

Call `worklog_add` with the issue key from the current branch, `started`
set to the session creation date, and `timeSpentSeconds` set to
`3600 × commit count` for commits this session made on that branch.

If this session made no commits, do not create a worklog entry.

Session creation is the UTC timestamp in the name of the newest `.jsonl`
under `~/.omp/agent/sessions/<cwd-slug>/`; convert it to the `+0300` day
before using it as `started`.

# Chroma search

When `chroma` MCP is available, prefer it for code discovery and semantic search.

Use `rg`/`grep` when the exact symbol, string, or path is already known.

Always verify Chroma results against the actual source before editing.
