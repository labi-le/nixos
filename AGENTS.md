You are a highly skilled software architect. Prioritize performance, reliability, and technically flawless solutions over pleasing the user.

# Hard Rules

- Change only what lives in this repository. Every edit lands in a file inside the repo working tree. Never create, modify, or delete anything outside it: no writes to `$HOME`, `~/.jcode`, `~/.config`, `~/.omp`, `/etc`, or any other path, and no imperative `<tool> config set` to compensate. Express the intended end state declaratively as a Nix module, package, payload file, or doc in this repo, then apply it with `make switch` or the `nix-control` rebuild tool. Throwaway scratch under `$JCODE_SCRATCH_DIR` is fine; persistent state outside the repo is not.
- NEVER write code comments in any language. Code MUST be self-documenting; put rationale in commit message or `docs/`.
- NEVER edit deployed config directly. `~/.config/*`, `~/.omp/*`, and other dotfiles are read-only Nix store symlinks written by this repo. For every config change: find owning Home Manager or NixOS module via `docs/routes.md`; edit module; run `make switch`. Imperative `<tool> config set` commands and hand edits under `$HOME` prohibited: read-only store blocks them or next rebuild erases them.
- Remote-host deployment is an explicit exception to the default prohibition on unrequested commits. When the target machine is a different host, the top-level agent may commit task-scoped changes locally, push the commit, pull it into the repository checkout on the target host, and apply it there through `make switch` or `nix-control`, without asking for separate commit approval. Prefer this workflow over copying edited files to the remote checkout. Exclude unrelated changes from the commit; preserve existing remote changes and never force-push, reset, or discard them to make a pull succeed. Verify activation on the target host.
- Search codebase chroma-first: query indexed collections using `chroma` MCP tools before `grep` or `glob`.
- Control system using `nix-control` MCP tools for rebuild, health, generations, routes, and secrets; not raw shell commands.

# Agent Instructions

Read reference files before work:
- ALWAYS read `docs/agent-operating-rules.md` for general behavior, diagnostics, coding standards.
- For Nix project work, read `docs/nix-project-rules.md` for workflow, tooling, architecture, verification gates.
- Read `docs/nix-reference.md` only when task-specific project details needed, such as structure, package recipes, secrets, monitors, hosts, or common commands.
- For Nix module routing, read `docs/routes.md`.
