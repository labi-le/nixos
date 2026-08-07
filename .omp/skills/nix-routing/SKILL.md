---
name: nix-routing
description: Use when about to edit any .nix file in this project — determines the exact file to modify via docs/routes.md without glob/grep/any search. Also use after creating a new module — update the routing table.
---

# Nix Module Routing

## One-Action Dispatch

When you receive any task that involves editing Nix files:

1. **Call `mcp__nixcfg_route`** with the task in plain language (optionally `host`). It ranks the rows of `docs/routes.md` and returns the exact file(s), the section, host scope, notes, and whether each path still exists. `mcp__nixcfg_route_file` does the reverse lookup for a path you already have.
2. **Fall back to `Read docs/routes.md`** only if the server is unavailable — it contains the same mapping of every task/concern to an exact `.nix` file and host scope.
3. **FORBIDDEN: glob, grep, or any file search.** The routing table already gives you the path. Open that file directly with Read.
4. Only if the concern is NOT listed (`confident: false`, or `routed: false` from `route_file`): search with glob/grep, then **add the new entry** to routes.md.

Searching after routing is pure waste of context and tokens.

## Updating the Routing Table

After creating a new module or adding an import to any host config, update `docs/routes.md`:

- **New NixOS module** → add row under the appropriate section (System/Desktop/PC/FX516/Notebook/Server)
- **New Home Manager module** → add row under Home Manager section
- **New cross-cutting task** → add row under Cross-Cutting Tasks
- **Module removed** → delete its row

Always include: task description, exact file path, host scope (if applicable).

## Sections in routes.md

| Section | When to add |
|---|---|
| System Modules | Imported via `modules/base.nix` (all hosts) |
| Desktop-Only Modules | Imported by 2+ desktop hosts |
| PC-Specific | `hosts/configuration.nix` imports |
| FX516-Specific | `hosts/configuration-fx516.nix` imports |
| Notebook-Specific | `hosts/configuration-notebook.nix` imports |
| Server-Specific | `hosts/configuration-server.nix` imports |
| Home Manager | `home-manager/modules/default.nix` imports |
| Cross-Cutting Tasks | Multi-file workflows |
