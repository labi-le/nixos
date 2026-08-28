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
