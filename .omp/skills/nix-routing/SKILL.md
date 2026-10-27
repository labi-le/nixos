---
name: nix-routing
description: Use when about to edit any .nix file in this project — resolves the exact file to modify through the nix-control route tool and docs/routes.toml. Also use after creating, moving or deleting a module.
---

# Nix Module Routing

## One-Action Dispatch

`docs/routes.toml` is the registry: `[[route]]` entries with `group`, `task`,
aliases, exact `paths`, explicit `hosts`, an optional one-line `note`, an optional
`doc` link and optional `steps` for multi-file recipes. `docs/routes.md` is a
generated index, never edited by hand.

1. **Call `mcp__nix-control_route`** with the task in plain language, optionally
   with `host`. It returns ranked routes with `group`, `task`, `paths`, `hosts`,
   `evidence` and path existence. `evidence` shows why a route matched: task,
   alias, path, group, note or doc tokens.
2. **Trust `confident: true` when the evidence is task, alias or path.** A match
   that rests only on note or doc text sets `caveat`; confirm the path before
   editing. `confident: false` means check with `route_file` or a targeted search.
3. **Use `route_file`** for a path you already have: it lists every route that
   owns the file, or says the file is unrouted.
4. **Fall back to `Read docs/routes.md`** only when the MCP server is unavailable.
   It carries the same tasks, paths and hosts in a readable table.
5. Only when a task is not routed: search with `glob`/`grep`, then add a
   `[[route]]` entry.

## Updating The Registry

- **New, moved or deleted module** → add or fix its `[[route]]` entry, then run
  `python3 .omp/nix-control-mcp/routes.py --index` to regenerate `docs/routes.md`.
- **Longer explanation** → keep it out of the registry: put it under a new heading
  in `docs/routes-notes.md` and reference `docs/routes-notes.md#<anchor>` from the
  route's `doc` field.
- **Current values, incident history, measurements** → the owning module or the
  per-service document under `docs/`, never a second copy in the registry.
- **Host scope** → list it explicitly. The audit compares entries with the
  `hosts/configuration*.nix` imports a route mentions.
- **After editing** → `routes_audit` reports dead paths, duplicate owners, groups,
  missing note anchors, unrouted `.nix` files and whether the index is stale.

## Groups

| Group | When to use |
|---|---|
| System Modules | Imported via `modules/base.nix` |
| Desktop-Only Modules | Imported by several desktop hosts |
| PC-Specific Modules | `hosts/configuration.nix` imports |
| FX516-Specific Modules | `hosts/configuration-fx516.nix` imports |
| Notebook-Specific Modules | `hosts/configuration-notebook.nix` imports |
| Server-Specific Modules | `hosts/configuration-server.nix` imports |
| Home Manager Modules | `home-manager/modules/default.nix` imports |
| Cross-Cutting Tasks | Multi-file recipes with `steps` |
| Optional / Currently Unimported Modules | Present but inactive |
| Other Files | Flake, overlays, docs, tooling |

## Boundaries

Routing maps tasks to files. It does not prove a value is current, and it does not
replace reading the module before editing. `confident` means the registry matched
well, not that the code agrees with the note.
