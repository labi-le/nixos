# modules/ — Shared NixOS System Modules

Routing (file ↔ concern) → `../docs/routes.md`. Conventions + verification gate → `../docs/nix-project-rules.md`.
Below = only what those don't cover.

## Module idiom

- Header `{ pkgs, ... }:` — add `config`/`lib` only when used.
- Simple feature = plain config attrset (e.g. `docker.nix`).
- Parameterized = `options.<name>` + `config = lib.mkIf ...`; values set per-host
  (e.g. `monitors.nix`, `hotkeys.nix`, `ide/module.nix`, `packages.desktop`/`packages.server`).

## Subtree gotchas

- These have a `default.nix` that imports siblings: `network/`, `nixvim/`, `syncthing/`, `nvidia/`, `awg/`, `shell/`.
- `ide/` is a SELF-CONTAINED FLAKE (`path:./modules/ide` input in `../flake.nix`, ships `plugin.jar`).
  Edit `ide/module.nix`; it is consumed as a flake module, not a plain import.
