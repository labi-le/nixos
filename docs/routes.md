# Module Routing Table

STOP.Do NOT use glob, grep, or any search tool. Read this file. Find your task. Open the listed file directly. You already have the answer.

## How to use

1. Find your task in the table below
2. Read the indicated file with Read tool
3. Make your changes
4. Do NOT search — the path is already given

## Host Legend

| Host | Desktop | Home Manager |
|------|---------|-------------|
| pc | ✓ | ✓ |
| fx516 | ✓ | ✓ |
| notebook | ✓ | ✓ |
| server | ✗ | ✗ |

## System Modules (all hosts via `modules/base.nix`)

| Task / Concern | File | Notes |
|---|---|---|
| Bootloader, kernel parameters | `modules/boot.nix` | |
| Sudo configuration | `modules/sudo.nix` | |
| Systemd services | `modules/systemd.nix` | |
| Journald logging | `modules/journald.nix` | |
| ZSH configuration | `modules/shell.nix` | |
| tmux terminal multiplexer (prefix `Ctrl+a`) | `modules/tmux.nix` | |
| Display monitors (declarations) | `modules/monitors.nix` | Values set in per-host config |
| Docker daemon | `modules/docker.nix` | |
| Polkit rules | `modules/polkit.nix` | |
| NVMe drive tuning | `modules/nvme.nix` | |
| GNOME keyring | `modules/keyring.nix` | |
| Locale, timezone | `modules/locale.nix` | |
| User accounts, shell aliases, Home Manager wiring | `modules/users.nix` | |
| OpenCode secrets for Home Manager hosts | `modules/opencode-secrets.nix` | Enabled for hosts listed in the module |
| Environment variables | `modules/env.nix` | |
| Network entry point | `modules/network/default.nix` | Imports DNS, firewall, hosts, proxy sub-modules |
| Network DNS | `modules/network/dns.nix` | Imported by `modules/network/default.nix` |
| Network firewall | `modules/network/firewall.nix` | Imported by `modules/network/default.nix` |
| Network hosts injection | `modules/network/hosts.nix` | Imported by `modules/network/default.nix` |
| Network proxy | `modules/network/proxy.nix` | Imported by `modules/network/default.nix` |
| System packages (all hosts) | `modules/packages.nix` | |
| OpenSSH daemon | `modules/ssh.nix` | |
| Remote Nix builders | `modules/builders.nix` | |
| Sway hotkeys | `modules/hotkeys.nix` | |
| nix-search-tv | `modules/nix-search-tv.nix` | |
| nix-ld dynamic loader (FHS shim) | `modules/nix-ld.nix` | Libraries for prebuilt Python wheels / ML runtimes |
| Neovim (nixvim) entry point | `modules/nixvim/default.nix` | Imports plugin and keymap sub-modules |
| Neovim plugins | `modules/nixvim/plugins.nix` | Imports/uses plugin component files in `modules/nixvim/` |
| Neovim keymaps | `modules/nixvim/keymaps.nix` | Imported by `modules/nixvim/default.nix` |
| Neovim completion | `modules/nixvim/cmp.nix`, `modules/nixvim/blink.nix` | Plugin component files |
| Neovim LSP/debug/format/search | `modules/nixvim/lsp.nix`, `modules/nixvim/dap.nix`, `modules/nixvim/conform.nix`, `modules/nixvim/telescope.nix` | Plugin component files |
| Neovim UI tabs | `modules/nixvim/barbar.nix` | Plugin component file |
| Stylix theming | `modules/stylix.nix` | |
| Flake registry `dev` (global dev shell access) | `modules/shell/registry.nix` | Added to `commonModules` in `flake.nix` |

## Desktop-Only Modules (per-host config)

| Task / Concern | File | Active Hosts |
|---|---|---|
| Desktop packages | `modules/packages-desktop.nix` | pc, fx516, notebook |
| Sound / audio | `modules/sound.nix` | pc, fx516, notebook |
| Wayland | `modules/wayland.nix` | pc, fx516, notebook |
| Greeter (SDDM) | `modules/greeter.nix` | pc, fx516, notebook |
| NFS mounts | `modules/nfs.nix` | pc, fx516, notebook |
| Thunar file manager | `modules/thunar.nix` | pc, fx516, notebook |
| JetBrains IDE wrapper module | `modules/ide/module.nix` | flake common module; enabled by host `ide.*` options on pc/notebook |
| Work mount secrets | `modules/work-mount.nix` | pc, notebook |

## PC-Specific Modules (`hosts/configuration.nix`)

| Task / Concern | File |
|---|---|
| PC host config entry point | `hosts/configuration.nix` |
| Home drive mount | `modules/home-drive.nix` |
| AMD GPU (Radeon) | `modules/radeon.nix` |
| AMD GPU (extra) | `modules/amd/default.nix` |
| UxPlay (AirPlay) | `modules/uxplay.nix` |
| Virtual machines / libvirt (disabled) | `modules/vm.nix` |
| Kernel (CachyOS) | `modules/kernel-cachyos.nix` |
| Steam | `modules/steam.nix` |
| Esync | `modules/esync.nix` |
| ADB (Android Debug Bridge) | `modules/adb.nix` |
| Bluetooth | `modules/bluetooth.nix` |
| Gamepad support | `modules/gamepad.nix` |
| Vial (keyboard) | `modules/vial.nix` |
| K3s | `modules/k3s.nix` |
| Firefox | `modules/firefox.nix` |
| Syncthing (pc) | `modules/syncthing/pc.nix` |
| Syncthing common module | `modules/syncthing/default.nix` |
| Syncthing device IDs | `modules/syncthing/devices.nix` |
| Syncthing Caddy reverse proxy | `modules/syncthing/caddy.nix` |
| Monitor values (pc) | `hosts/configuration.nix` (monitors attrset) |
| Hardware (pc) | `hosts/hardware-pc.nix` |
| belphegor, openrgb, gnupg, dconf | `hosts/configuration.nix` |

## FX516-Specific Modules (`hosts/configuration-fx516.nix`)

| Task / Concern | File |
|---|---|
| FX516 host config entry point | `hosts/configuration-fx516.nix` |
| Kernel (Zen) | `modules/kernel-zen.nix` |
| NVIDIA GPU | `modules/nvidia/default.nix` |
| NVIDIA Prime | `modules/nvidia/prime.nix` |
| Thunderbolt | `modules/thunderbolt.nix` |
| Monitor values (fx516) | `hosts/configuration-fx516.nix` (monitors attrset) |
| Hardware (fx516) | `hosts/hardware-fx516.nix` |

## Notebook-Specific Modules (`hosts/configuration-notebook.nix`)

| Task / Concern | File |
|---|---|
| Notebook host config entry point | `hosts/configuration-notebook.nix` |
| Kernel (Zen) | `modules/kernel-zen.nix` |
| Thunderbolt | `modules/thunderbolt.nix` |
| Battery management | `modules/battery.nix` |
| Hibernation | `modules/hibernation.nix` |
| ADB | `modules/adb.nix` |
| Bluetooth | `modules/bluetooth.nix` |
| Steam | `modules/steam.nix` |
| Syncthing (notebook) | `modules/syncthing/notebook.nix` |
| IDE host options (notebook) | `hosts/configuration-notebook.nix` (ide attrset) |
| Monitor values (notebook) | `hosts/configuration-notebook.nix` (monitors attrset) |
| Hardware (notebook) | `hosts/hardware-notebook.nix` |

## Server-Specific Modules (`hosts/configuration-server.nix`)

| Task / Concern | File |
|---|---|
| Server host config entry point | `hosts/configuration-server.nix` |
| Server packages | `modules/packages-server.nix` |
| Nginx | `modules/nginx.nix` |
| ZeroSSL ACME for nginx | `modules/zerossl.nix` |
| LiteLLM | `modules/litellm.nix` |
| Drive mounts | `modules/drive.nix` |
| Kernel (CachyOS) | `modules/kernel-cachyos.nix` |
| Grafana | `modules/grafana.nix` |
| Prometheus, Loki, Alloy (ships nginx/angie + docker container + fail2ban logs to Loki) | `modules/grafana.nix` |
| Grafana monitoring aggregator (imports shared contact points + per-service alert files) | `modules/monitoring/default.nix` |
| Grafana shared notification channels (Telegram contact point + agenix secret, reused by all alerts) | `modules/monitoring/contact-points.nix` |
| Grafana alert: tidal-syncer TIDAL re-login required (Loki log alert) | `modules/monitoring/tidal-syncer.nix` |
| FRP (Fast Reverse Proxy) | `modules/frp.nix` |
| Syncthing (server) | `modules/syncthing/server.nix` |
| Syncthing common module | `modules/syncthing/default.nix` |
| Syncthing device IDs | `modules/syncthing/devices.nix` |
| Syncthing Caddy reverse proxy | `modules/syncthing/caddy.nix` |
| NVIDIA GT 210 | `modules/nvidia/gt210.nix` |
| Vaultwarden | `modules/vaultwarden.nix` |
| qBittorrent | `modules/qbittorrent.nix` |
| AmneziaWG | `modules/awg/default.nix` |
| AmneziaWG compose stack | `modules/awg/compose.nix` |
| Network (server) | `modules/network/default.nix` |
| GitLab (disabled) | `modules/gitlab.nix` |
| ChromaDB vector database service | `modules/chromadb.nix` |
| Hardware (server) | `hosts/hardware-server.nix` |

## Home Manager Modules (desktop only, `home-manager/modules/default.nix`)

| Task / Concern | File |
|---|---|
| HM entry point | `home-manager/modules/default.nix` |
| Sway window manager | `home-manager/modules/sway.nix` |
| Waybar status bar | `home-manager/modules/waybar.nix` |
| Wofi launcher | `home-manager/modules/wofi.nix` |
| Mako notifications | `home-manager/modules/mako.nix` |
| Git user config | `home-manager/modules/git.nix` |
| Alacritty terminal | `home-manager/modules/alacritty.nix` |
| SSH user config | `home-manager/modules/ssh.nix` |
| MIME type associations | `home-manager/modules/mimeapps.nix` |
| mpv media player | `home-manager/modules/mpv.nix` |
| EasyEffects audio | `home-manager/modules/easyeffects.nix` |
| Yazi file manager | `home-manager/modules/yazi.nix` |
| Thunar (user config) | `home-manager/modules/thunar.nix` |
| yt-dlp | `home-manager/modules/yt-dlp.nix` |
| XDG user dirs | `home-manager/modules/xdg.nix` |
| PiDev coding agent | `home-manager/modules/pidev.nix` |
| Oh My Pi (omp) coding agent + undo-redo extension | `home-manager/modules/omp.nix` | omp-flake HM module loaded in `flake.nix` sharedModules |
| OpenCode (LLM agents) entry point | `home-manager/modules/opencode/default.nix` |
| OpenCode provider definitions | `home-manager/modules/opencode/providers/*.nix` |
| OpenCode package wiring | `home-manager/modules/opencode/packages.nix` |
| OpenCode agents | `home-manager/modules/opencode/agents.nix` |
| OpenCode integrations | `home-manager/modules/opencode/integrations.nix` |
| OpenCode LSP servers (per-language) | `home-manager/modules/opencode/lsp/default.nix` imports `go.nix`, `php.nix`, `nix.nix` |
| OpenCode wrapper scripts (splices the `index-repo` opencode hook: registers `$PWD` with the shared indexer service on launch, unregisters on exit) | `home-manager/modules/opencode/wrappers.nix` |
| Code indexer (`index-repo`) — Rust crate + Nix modules; lives in its own repo `git+ssh://git@github.com/labi-le/index-repo` | external flake input (`flake.nix`); see "Code indexer wiring" below |

## Cross-Cutting Tasks

| Task | Step 1 | Step 2 | Step 3 |
|---|---|---|---|
| Add package from flake input | `flake.nix` (add input) | `overlays.nix` (add overlay) | `modules/packages.nix` or `packages-desktop.nix` or `packages-server.nix` |
| Add local package | `pkgs/<name>.nix` (create) | `overlays.nix` (add) | `modules/packages.nix` or `packages-desktop.nix` or `packages-server.nix` |
| Add AGenix secret | `secrets/<name>.age` (encrypt) | host config (add `age.secrets.<name>`) | |
| Add new NixOS module | `modules/<name>.nix` (create) | `modules/base.nix` or per-host config (add import) | |
| Add a Grafana alert for a service | `modules/monitoring/<service>.nix` (create, with `services.grafana.provision.alerting.rules`) | `modules/monitoring/default.nix` (add import) | route to the `telegram` contact point via `notification_settings.receiver` |
| Add new HM module | `home-manager/modules/<name>.nix` (create) | `home-manager/modules/default.nix` (add import) | |

## Code indexer wiring (`index-repo`)

The indexer is an external flake (`index-repo.url` in `flake.nix`) that ships its own Nix modules. Wiring lives in three places:

| Concern | File | What |
|---|---|---|
| Package overlay | `overlays.nix` | `index-repo = inputs.index-repo.packages.${system}.default` (→ `pkgs.index-repo`) |
| System service | `flake.nix` (`mkSystem` `withHomeManager` list) | imports `inputs.index-repo.nixosModules.default` + sets `services.index-repo.enable = true` (HM hosts only, not server) |
| Opencode glue | `flake.nix` (`homeManagerConfig.sharedModules`) + `home-manager/modules/opencode/{default,wrappers}.nix` | imports `inputs.index-repo.homeManagerModules.default`; the wrapper splices `config.services.index-repo.opencode.hook` |
| Chroma gate + MCP | `home-manager/modules/opencode/integrations.nix` | sets `services.index-repo.opencode.chromaGate.enable` (deploys the `chroma-gate.ts` opencode plugin from the index-repo flake) + `chromaMcp.{enable,host}` (emits `programs.opencode.settings.mcp.chroma`, the `uvx chroma-mcp` server) |

Connection options (ChromaDB host/port/ssl, debounce) are `services.index-repo.{host,port,ssl,debounce}` on the NixOS module. The systemd user unit (`index-repo serve`) is defined by the module — do NOT hand-write it. The opencode chroma-gate plugin + `chroma` MCP server come from the same index-repo HM module (`services.index-repo.opencode.{chromaGate,chromaMcp}`, enabled in `integrations.nix`); `chromaMcp.{host,port,ssl}` default to the NixOS `services.index-repo.{host,port,ssl}` via `osConfig`.

## Optional / Currently Unimported Modules

| Task / Concern | File | Notes |
|---|---|---|
| Generic latest kernel | `modules/kernel.nix` | Not imported by active host configs |
| Virtual machines / libvirt | `modules/vm.nix` | Commented in `hosts/configuration.nix` |
| Spicetify | `modules/spicetify.nix` | Not imported by active host configs |
| DPI bypass proxy | `modules/dpi.nix` | Not imported by active host configs |
| EarlyOOM | `modules/earlyoom.nix` | Not imported by active host configs |
| GitLab | `modules/gitlab.nix` | Commented in `hosts/configuration-server.nix` |

## Other Files

| File | Purpose |
|---|---|
| `flake.nix` | Flake inputs, outputs, host wiring |
| `modules/shell/devshells.nix` | Per-language dev shells (`nix develop dev#<lang>`); imported by `flake.nix` outputs |
| `overlays.nix` | Custom package overlays |
| `settings.nix` | Common settings (nix settings, allowed packages) |
| `Makefile` | Convenience targets: `switch`, `boot`, `upgrade`, `fmt`, `cleanup`, `optimise` |
