Read the caveman skill in ultra mode and answer in that mode for every response.

# Subagent supervision

These rules apply only while subagents are actually running.

- A worker reporting `completed` is not proof. Verify its result before relying on it.
- Judge liveness by last activity, not total runtime. Builds and broad searches may legitimately remain silent for several minutes.
- If a worker is stale for roughly 15 minutes, read its transcript first. Send a status probe only when the transcript appears frozen.
- If it remains frozen on the next probe, cancel it and redispatch a narrower task.
- Do not supervise, probe, or spawn agents when the current task does not require delegation.
- Deep task graphs grow by design; rate the graph by whether the current frontier is on-topic, not by node count. Stop a graph whose frontier has drifted off the request.

# Task workflow

Follow `~/AGENTS.md` for execution, delegation, verification, and review.

A tracker-keyed task does not by itself require delegation or independent review. Do not create a reviewer merely because an issue key or tracker task exists.

When relevant verification passes and the requested behavior is complete, finish the task. Do not start additional review/fix cycles without a concrete reason defined by `~/AGENTS.md`.

# Jira worklog

When a task is finished and this session has a jira worklog MCP server, log time before yielding.

Call its `worklog_add` tool with the issue key from the current branch, `started` set to the session creation date, and `timeSpentSeconds` set to `3600 × commit count` for commits this session made on that branch.

If this session made no commits, do not create a worklog entry.

# Chroma search

When the `chroma` MCP server is available, prefer it for code discovery and semantic search.

Use `agentgrep`/`rg`/`grep` when the exact symbol, string, or path is already known.

Always verify Chroma results against the actual source before editing.

# Comments and examples in code

A comment is warranted only where the code cannot speak for itself; if the reader can already see what the line does, delete the comment. Explain why, never what. A comment running past a line or two is a sign the code needs a better name or a smaller function: fix the code instead of narrating it. Rationale that genuinely needs length belongs in the commit message or under `docs/`. Never leave a scaffolding marker (`TODO`, `FIXME`, `XXX`, `HACK`) or commented-out code behind: git remembers what was deleted, and a marker is a promise nobody keeps. Examples inside comments, docstrings and fixtures stay neutral: real hostnames, IP addresses, emails, ticket-less internal URLs, absolute home paths and anything copied out of a production log get replaced by `foo`, `bar`, `user@example.com`, `192.0.2.1` or `example.com`, and credentials and tokens are never pasted at all, not even shortened. The `pre_tool` gate refuses the mechanical cases: markers, commented-out code, real data, credential shapes. Prose files are not code: a match inside markdown or a document is a false positive.

# Commit style

Subject is `COMPONENT: SHORT DESCRIPTION`: the component is the module, host or package the change belongs to (`jcode:`, `omp:`, `pc:`, `nginx:`, `flake:`, `server:`, `JIRA-1234:`), in either case, spanning at most three space-separated words, and the text after the colon is imperative in either case. Median subject is under 30 characters; treat 70 as the hard ceiling. The message is that one line and nothing more: a newline inside `-m` is refused, a second `-m` is refused, and a decision the diff cannot show belongs in `docs/`, not in a body. The message is raw literal text: a value built from `$VAR`, `$(…)` or backticks is refused, and so are `-F`, `--file`, `-t`, `--template`, `-e`, `--edit`, editor overrides such as `GIT_EDITOR=` and config overrides such as `-c core.editor=` or `-c commit.template=`: the text has to sit in the command, with no side effect producing it. A commit with no `-m` at all is refused too. Never restate the diff, list touched files, or append generated trailers.

# Project naming

This binds only when something new gets a proper name: a project, a repo, a binary, a service, a host. Variables, functions, types, files and branches inside an existing codebase follow that codebase's own conventions, never this register.

The register is demonology and imperial gothic: the Seven Princes of Hell and the Ars Goetia grimoires (Belphegor, Astaroth). Keep the sources straight. Belphegor is not among the Ars Goetia's seventy-two spirits; he is a Prince of Hell from Binsfeld's classification and the Dictionnaire Infernal. Attribute an entity to the grimoire it actually comes from.

Make the myth carry the function: Belphegor is the demon of ingenious labour-saving inventions, which is why he owns the clipboard daemon. A name that is merely ominous is noise; the entity's domain must map onto what the code does. Offer two or three candidates and state the mapping in one line each.

Never reuse a name already taken by one of the user's repos. Known spent: `belphegor`, `belphegor-mobile`, `astaroth-*`, `thief`, `tempest`. This list is a floor, not the truth: run `gh repo list --limit 200` before proposing.
