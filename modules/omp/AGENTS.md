# Scope
Only sections marked (top-level) bind the user-facing session. Subagents follow their briefs, complete them, and yield; no supervising other agents or starting review/fix loops unless explicitly requested in the brief.

# Operating principle (top-level)
Work directly by default; delegation is an optimization, not required. Do not spawn an agent if direct work is faster and clearer: brief-writing, waiting, and validation costs must be justified by work moved out of the parent session. The top-level agent may inspect/edit files, run commands, and verify directly.

# Delegation (top-level)
Delegate only for clear benefit:
- `scout`: non-trivial discovery when relevant code or ownership is genuinely unclear, especially across directories/subsystems; not for simple grep, read, or obvious lookup.
- `sonic`: repetitive mechanical, low-judgment work across many independent locations; no design decisions or subtle correctness work.
- `task`: substantial bounded implementation that saves meaningful parent effort or can proceed independently.

Agent availability alone is no reason to delegate. Prefer direct work for small edits, obvious fixes, localized changes, documentation, configuration tweaks, straightforward tests, simple searches, or tasks whose context takes roughly as much effort to explain as the task takes to do. Prefer one worker; fan out only if tasks are genuinely independent and parallelism materially helps.

Every delegated brief: goal, relevant files/search area, constraints, acceptance criteria; include known relevant tests, linters, type checks, or other project verification. Workers do not commit. Do not create a commit unless the user requests it or surrounding workflow explicitly requires it.

# Task workflow (top-level)
1. **Understand:** Inspect enough context to determine scope and risk; handle trivial discovery directly.
2. **Execute:** Edit directly unless delegation clearly helps; validate delegated results before accepting them.
3. **Verify:** Run the smallest relevant check that gives useful confidence: targeted tests, type checking, linting, build checks, or direct inspection, as appropriate. Avoid expensive broad checks when the change cannot reasonably affect them.
4. **Review decision:** `reviewer` optional, not mandatory; spawn only when independent judgment materially helps. Review normally justified if at least one applies:
   - User explicitly requests review or audit.
   - Authentication, authorization, permissions, secrets, cryptography, or another security boundary changed.
   - Persistence, migrations, transactions, or destructive data handling changed.
   - Concurrency, synchronization, caching, or lifecycle behavior is non-trivial.
   - Public API, protocol, schema, serialization format, or compatibility contract changed.
   - Change crosses several subsystems or has large behavioral surface.
   - Correctness relies on subtle invariants or edge cases inadequately established by tests.
   - Implementation is in unfamiliar/poorly understood code, and independent inspection would materially reduce uncertainty.

   Skip reviewer for small localized fixes, mechanical changes, documentation, simple configuration changes, formatting, obvious refactors, or other low-risk work when direct inspection plus relevant verification suffices.
5. **Handle findings:** Findings are evidence, not commands; check each against code, tests, and user request before acting. Fix valid P0/P1 before finishing. Fix P2 if it identifies a concrete in-scope correctness, reliability, security, or requested-behavior problem; report or ignore speculative, unrelated, or merely optional P2 instead of expanding scope. P3 never triggers a fix loop. Fix small issues directly; delegate a fix only if it independently meets delegation criteria. Reject incorrect findings with concrete code, test, or request evidence; severity labels do not override evidence.
6. **Re-review only when warranted:** Rerun relevant verification after a fix; do not automatically spawn another reviewer. Re-review only for an original finding concerning a high-risk invariant or a fix materially changing behavior beyond that finding. Normally at most one re-review. If reviewer and implementation keep disagreeing, adjudicate using code, verification results, and user requirements; no open-ended review/fix loop.
7. **Finish:** Stop once requested behavior is implemented and relevant verification passes. Do not invent work to exercise agents or complete a ritual workflow.
