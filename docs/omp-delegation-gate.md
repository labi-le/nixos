# OMP delegation gate

`modules/omp/extensions/delegation-gate.ts` runs on the main session's `session_stop` event. It reads the latest durable `todo` snapshot on the active branch, the active session's `task.maxConcurrency` setting, and the session's running async-job count. If actionable work remains and a slot is available, it blocks completion and asks the orchestrator to reconsider delegation.

The gate does not launch agents or require filling every available slot. Delegate only a concrete independent task when dispatch saves more work than briefing and integrating it costs. Handle small edits, integration, and verification directly. Completed and blocked todo items do not trigger the gate. Each todo update or newly settled subagent permits one new reminder. Without either change, repeated stop attempts do not loop.

This is a stop-time check, not a continuous utilization monitor. OMP defers `session_stop` until its agent-owned background jobs are idle, so the check specifically catches the case where subagents have finished but the todo still has actionable work. The orchestrator still owns the decision about whether a remaining task is independently delegable.
