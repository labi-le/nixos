# home-manager/modules/ — User-level (Home Manager) config

Routing + "add an HM module" → `../../docs/routes.md`. This is user config, NOT system config.

## Scope rule (the key distinction from `../../modules/`)

- Use HM namespaces: `home.*`, `programs.*`, `wayland.windowManager.sway`, user `services.*`.
- NEVER system namespaces here (`environment.systemPackages`, `systemd.services`, `networking.*`) — those go in `../../modules/`.
- User packages → `home.packages`. Reach NixOS config → the `osConfig` arg.

## Gotchas

- Embedded via `../../modules/users.nix` (`home-manager.users.<user>`); no `homeConfigurations` output.
- `../home.nix` pins `home.stateVersion = "26.05"` — independent from system `"24.11"`; do not align them.
- `../../modules/steam.nix` ALSO writes `home-manager.users.<user>` directly — a second HM patch point outside this tree.
