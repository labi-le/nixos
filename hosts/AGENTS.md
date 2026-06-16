# hosts/ — Per-machine configuration

Routing → `../docs/routes.md`. Recipes (monitors, packages, hosts list) → `../docs/nix-reference.md`.

## Doc-absent facts

- `configuration.nix` = **pc** (no `-pc` suffix); the others are `configuration-<host>.nix`.
- `hardware-<host>.nix` is generated (`make generate-hardware`) and injected by `mkSystem` — do not hand-edit.
- Hosts are assembled in `../flake.nix` via `mkSystem <name> <configFile> <withHomeManager>` → `nixosConfigurations.<name>`.
- Home Manager is embedded through `../modules/users.nix`; there is NO `homeConfigurations` output (desktop hosts only).

## Adding a host (not in routes.md)

1. Create `hosts/configuration-<name>.nix` + `hosts/hardware-<name>.nix`.
2. Register both in `../flake.nix` via `mkSystem` (set `withHomeManager` if user config is needed).
