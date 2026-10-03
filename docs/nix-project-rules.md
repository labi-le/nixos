# Nix Project Rules

## Module Routing

- Use the `nix-routing` skill. It determines the target file via
  `docs/routes.md` in one action, forbids `glob`/`grep` module discovery, and
  keeps the routing table updated.
- `docs/routes.md` is only for file navigation. For external NixOS/Home Manager
  package or option documentation, use MCP tools such as `nixos_nix`.

## Required Tooling

- Use Context7 MCP for library and framework documentation before implementing
  any feature or answering programming questions. Call
  `context7_resolve-library-id`, then `context7_query-docs`.
- Check available skills before work and use only the ones that are relevant to
  the current task.
- Use `nixos_nix` and `nixos_nix_versions` for NixOS/Home Manager packages,
  options, and version history. Do not scrape web pages or search GitHub for
  nixpkgs documentation.
- Fetch fresh context before writing or modifying Nix files. Check current
  options first. For non-Nix libraries, use Context7.

## Conventions

- Add new packages through `overlays.nix` following existing patterns.
- Use agenix for secrets management.

## Architecture And Decision Rules

- Use overlay-first package wiring. If a package comes from a flake input and is
  used in NixOS modules, expose it in `overlays.nix` first, then consume it as
  `pkgs.<name>` in modules. Avoid direct `inputs.<name>...` package references
  inside modules.
- Measure before and after performance-related changes with the same command.
- Use the narrowest dataset or index that satisfies the runtime use case. Use
  broader data only for exploratory or debugging workflows.
- Treat evaluation and deprecation warnings as defects in the same task. Do not
  leave them unresolved.
- When overriding shell handlers, use explicit merge ordering such as
  `lib.mkAfter` or `lib.mkBefore` to avoid accidental override by other modules.
- If `flake.nix` inputs change, include the corresponding `flake.lock` update in
  the same change set.

## Makefile Resource Limits

The `switch`, `boot`, `upgrade`, and `dry-run` targets use a user scope
with `MEMORY_HIGH=8G` for reclaim/throttling and `MEMORY_MAX=10G` as an
emergency hard limit. Swap remains disabled inside that scope. The hard
limit can still cause an OOM kill; these settings do not guarantee that a
build fits in memory or completes.

Build parallelism defaults to `MAX_JOBS=1` and `CPUS=2`. These control
concurrent local derivations and the suggested cores per derivation,
respectively. Override them explicitly, for example:
`make switch MAX_JOBS=1 CPUS=4 MEMORY_HIGH=8G MEMORY_MAX=12G`.

The scope covers the client, evaluation, and direct descendants. Work
delegated to the separately running Nix daemon or remote builders does
not inherit its memory limits. The nix-control rebuild tool has its own
invocation and does not consume these Makefile variables.

## Verification Gate

- Verification succeeds only when `switch` exits 0 with no failed units and no
  new evaluation or deprecation warnings. The expected `Git tree is dirty`
  warning is excluded.
- For performance-sensitive changes, include a quick benchmark check in the
  verification output.
