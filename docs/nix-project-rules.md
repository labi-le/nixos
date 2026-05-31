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
- Use the `using-superpowers` skill when available. Check relevant skills before
  work.
- Use `nixos_nix` and `nixos_nix_versions` for NixOS/Home Manager packages,
  options, and version history. Do not scrape web pages or search GitHub for
  nixpkgs documentation.
- Fetch fresh context before writing or modifying Nix files. Check current
  options first. For non-Nix libraries, use Context7.
- Before asking the user to run `make switch`, run formatting and a dry-run
  build for the target host. For `pc`, use:

```bash
nix-shell -p nixpkgs-fmt --command 'nixpkgs-fmt path/to/file.nix'
nix build .#nixosConfigurations.pc.config.system.build.toplevel --dry-run
```

## Conventions

- Format `.nix` files with `nixpkgs-fmt` before committing.
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

## Verification Gate

- Run formatting and a dry-run build before requesting `make switch`.
- Verification succeeds only when the dry-run passes and no new evaluation or
  deprecation warnings are present. The expected `Git tree is dirty` warning is
  excluded.
- For performance-sensitive changes, include a quick benchmark check in the
  verification output.
