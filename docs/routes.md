# Module Routing Table

STOP. Do NOT use glob, grep, or any search tool. Read this file. Find your task. Open the listed file directly. You already have the answer.

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
| Display monitors (declarations) | `modules/monitors.nix` | Values set in per-host config |
| Docker daemon | `modules/docker.nix` | |
| Polkit rules | `modules/polkit.nix` | |
| NVMe drive tuning | `modules/nvme.nix` | |
| GNOME keyring | `modules/keyring.nix` | |
| Locale, timezone | `modules/locale.nix` | |
| User accounts, shell aliases, Home Manager wiring | `modules/users.nix` | |
| Environment variables | `modules/env.nix` | |
| Network (DNS, firewall, hosts, proxy) | `modules/network/default.nix` | Sub-modules in `modules/network/` |
| System packages (all hosts) | `modules/packages.nix` | |
| OpenSSH daemon | `modules/ssh.nix` | |
| Remote Nix builders | `modules/builders.nix` | |
| Sway hotkeys | `modules/hotkeys.nix` | |
| nix-search-tv | `modules/nix-search-tv.nix` | |
| Neovim (nixvim) | `modules/nixvim/default.nix` | Sub-modules in `modules/nixvim/` |
| Stylix theming | `modules/stylix.nix` | |

## Desktop-Only Modules (per-host config)

| Task / Concern | File | Active Hosts |
|---|---|---|
| Desktop packages | `modules/packages-desktop.nix` | pc, fx516, notebook |
| Sound / audio | `modules/sound.nix` | pc, fx516, notebook |
| Wayland | `modules/wayland.nix` | pc, fx516, notebook |
| Greeter (SDDM) | `modules/greeter.nix` | pc, fx516, notebook |
| NFS mounts | `modules/nfs.nix` | pc, fx516, notebook |
| Thunar file manager | `modules/thunar.nix` | pc, fx516, notebook |

## PC-Specific Modules (`hosts/configuration.nix`)

| Task / Concern | File |
|---|---|
| PC host config entry point | `hosts/configuration.nix` |
| Home drive mount | `modules/home-drive.nix` |
| AMD GPU (Radeon) | `modules/radeon.nix` |
| AMD GPU (extra) | `modules/amd/default.nix` |
| UxPlay (AirPlay) | `modules/uxplay.nix` |
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
| IDE configuration | `modules/ide/module.nix` |
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
| Monitor values (notebook) | `hosts/configuration-notebook.nix` (monitors attrset) |
| Hardware (notebook) | `hosts/hardware-notebook.nix` |

## Server-Specific Modules (`hosts/configuration-server.nix`)

| Task / Concern | File |
|---|---|
| Server host config entry point | `hosts/configuration-server.nix` |
| Server packages | `modules/packages-server.nix` |
| Nginx | `modules/nginx.nix` |
| LiteLLM | `modules/litellm.nix` |
| Drive mounts | `modules/drive.nix` |
| Kernel (CachyOS) | `modules/kernel-cachyos.nix` |
| Grafana | `modules/grafana.nix` |
| FRP (Fast Reverse Proxy) | `modules/frp.nix` |
| Syncthing (server) | `modules/syncthing/server.nix` |
| NVIDIA GT 210 | `modules/nvidia/gt210.nix` |
| Vaultwarden | `modules/vaultwarden.nix` |
| qBittorrent | `modules/qbittorrent.nix` |
| AmneziaWG | `modules/awg/default.nix` |
| Network (server) | `modules/network/default.nix` |
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
| OpenCode (LLM agents) | `home-manager/modules/opencode/default.nix` |

## Cross-Cutting Tasks

| Task | Step 1 | Step 2 | Step 3 |
|---|---|---|---|
| Add package from flake input | `flake.nix` (add input) | `overlays.nix` (add overlay) | `modules/packages.nix` or `packages-desktop.nix` or `packages-server.nix` |
| Add local package | `pkgs/<name>.nix` (create) | `overlays.nix` (add) | `modules/packages.nix` or `packages-desktop.nix` or `packages-server.nix` |
| Add AGenix secret | `secrets/<name>.age` (encrypt) | host config (add `age.secrets.<name>`) | |
| Add new NixOS module | `modules/<name>.nix` (create) | `modules/base.nix` or per-host config (add import) | |
| Add new HM module | `home-manager/modules/<name>.nix` (create) | `home-manager/modules/default.nix` (add import) | |

## Other Files

| File | Purpose |
|---|---|
| `flake.nix` | Flake inputs, outputs, host wiring |
| `overlays.nix` | Custom package overlays |
| `settings.nix` | Common settings (nix settings, allowed packages) |
| `Makefile` | Convenience targets: `switch`, `boot`, `upgrade`, `fmt`, `cleanup`, `optimise` |
