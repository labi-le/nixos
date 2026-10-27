# Config routes

`docs/routes.toml` is the routing registry the `nix-control` route tool reads.
Edit that file, not this index; regenerate this page with
`python3 .omp/nix-control-mcp/routes.py --index`.

Use `route` for a task in plain language, `route_file` for a path, and
`routes_audit` to check dead paths, duplicate owners and unrouted modules.
Longer knowledge for a route lives in `docs/routes-notes.md`, linked by its `doc`
field. Current values belong in the modules; incident history belongs in the
per-service documents under `docs/`.

## Host legend

| Host | Desktop | Home Manager |
| --- | --- | --- |
| pc | yes | yes |
| fx516 | yes | yes |
| notebook | yes | yes |
| server | no | no |

## Route index

| Group | Task | Paths | Hosts | Notes |
| --- | --- | --- | --- | --- |
| System Modules | Bootloader, kernel parameters | `modules/boot.nix` | pc, fx516, notebook, server |  |
| System Modules | Sudo configuration, NOPASSWD rules | `modules/sudo.nix` | pc, fx516, notebook, server |  |
| System Modules | Persistent Rust/C/C++ compiler cache daemon | `modules/sccache.nix` | pc, fx516, notebook, server |  |
| System Modules | Systemd manager settings | `modules/systemd.nix` | pc, fx516, notebook, server |  |
| System Modules | Journald logging | `modules/journald.nix` | pc, fx516, notebook, server |  |
| System Modules | ZSH configuration | `modules/shell.nix` | pc, fx516, notebook, server |  |
| System Modules | tmux terminal multiplexer | `modules/tmux.nix` | pc, fx516, notebook, server | (prefix `Ctrl+a`) |
| System Modules | Terminal switch | `modules/terminal.nix` | pc, fx516, notebook, server | docs/routes-notes.md#terminal |
| System Modules | Display monitors | `modules/monitors.nix` | pc, fx516, notebook, server | (declarations); Values set in per-host config |
| System Modules | Docker daemon | `modules/docker.nix` | pc, fx516, notebook, server |  |
| System Modules | Polkit rules | `modules/polkit.nix` | pc, fx516, notebook, server |  |
| System Modules | NVMe drive tuning | `modules/nvme.nix`, `docs/nvme.md` | pc, fx516, notebook, server | docs/routes-notes.md#nvme |
| System Modules | GNOME keyring | `modules/keyring.nix` | pc, fx516, notebook, server |  |
| System Modules | Locale, timezone | `modules/locale.nix` | pc, fx516, notebook, server |  |
| System Modules | User accounts, shell aliases, Home Manager wiring | `modules/users.nix` | pc, fx516, notebook, server |  |
| System Modules | LLM gateway and provider API keys for omp/jcode hosts | `modules/opencode-secrets.nix` | pc, fx516, notebook, server | docs/routes-notes.md#opencode-secrets |
| System Modules | Environment variables | `modules/env.nix` | pc, fx516, notebook, server |  |
| System Modules | Network entry point | `modules/network/default.nix` | pc, fx516, notebook, server | Imports DNS, firewall, hosts, proxy sub-modules |
| System Modules | Network DNS | `modules/network/dns.nix` | pc, fx516, notebook, server | Imported by `modules/network/default.nix` |
| System Modules | Network firewall | `modules/network/firewall.nix` | pc, fx516, notebook, server | docs/routes-notes.md#firewall |
| System Modules | Network hosts injection | `modules/network/hosts.nix` | pc, fx516, notebook, server | Imported by `modules/network/default.nix` |
| System Modules | Network proxy | `modules/network/proxy.nix` | pc, fx516, notebook, server | Imported by `modules/network/default.nix` |
| System Modules | System packages | `modules/packages.nix` | pc, fx516, notebook, server | (all hosts) |
| System Modules | btop user config | `modules/btop.nix` | pc, fx516, notebook, server |  |
| System Modules | OpenSSH daemon | `modules/ssh.nix` | pc, fx516, notebook, server |  |
| System Modules | Remote Nix builders | `modules/builders.nix` | pc, fx516, notebook, server |  |
| System Modules | Sway hotkeys | `modules/hotkeys.nix` | pc, fx516, notebook, server |  |
| System Modules | nix-search-tv | `modules/nix-search-tv.nix` | pc, fx516, notebook, server |  |
| System Modules | nix-ld dynamic loader | `modules/nix-ld.nix` | pc, fx516, notebook, server | (FHS shim); Libraries for prebuilt Python wheels / ML runtimes |
| System Modules | Neovim (nixvim) entry point | `modules/nixvim/default.nix` | pc, fx516, notebook, server | Imports plugin and keymap sub-modules |
| System Modules | Neovim plugins | `modules/nixvim/plugins.nix` | pc, fx516, notebook, server | Imports/uses plugin component files in `modules/nixvim/` |
| System Modules | Neovim keymaps | `modules/nixvim/keymaps.nix` | pc, fx516, notebook, server | Imported by `modules/nixvim/default.nix` |
| System Modules | Neovim completion | `modules/nixvim/cmp.nix`, `modules/nixvim/blink.nix` | pc, fx516, notebook, server | Plugin component files |
| System Modules | Neovim LSP/debug/format/search | `modules/nixvim/lsp.nix`, `modules/nixvim/dap.nix`, `modules/nixvim/conform.nix`, `modules/nixvim/telescope.nix` | pc, fx516, notebook, server | Plugin component files |
| System Modules | Neovim UI tabs | `modules/nixvim/barbar.nix` | pc, fx516, notebook, server | Plugin component file |
| System Modules | Stylix theming | `modules/stylix.nix` | pc, fx516, notebook, server |  |
| System Modules | Flake registry `dev` | `modules/shell/registry.nix` | pc, fx516, notebook, server | (global dev shell access); Added to `commonModules` in `flake.nix` |
| System Modules | Oh My Pi (omp) coding agent | `modules/omp/default.nix` | pc, fx516, notebook, server | docs/routes-notes.md#omp |
| System Modules | Oh My Pi input, module and package overlay | `flake.nix`, `flake.lock`, `overlays.nix` | pc, fx516, notebook, server | docs/routes-notes.md#flake |
| System Modules | Jcode coding agent | `modules/jcode/default.nix` | pc, fx516, notebook, server | docs/routes-notes.md#jcode |
| System Modules | Local FreeDeepseekAPI profile for jcode | `modules/jcode/deepseek-web.nix`, `modules/jcode/deepseek-session.py` | pc, fx516, notebook, server | docs/routes-notes.md#deepseek-web |
| System Modules | OpenCode Go `space-bunny-free` capability override for jcode | `modules/jcode/space-bunny.nix` | pc, fx516, notebook, server | docs/routes-notes.md#space-bunny |
| System Modules | Maki coding agent | `modules/maki/default.nix` | pc, notebook, server | docs/routes-notes.md#maki |
| System Modules | Yazi file manager | `modules/yazi.nix` | pc, fx516, notebook, server | docs/routes-notes.md#yazi |
| Desktop-Only Modules | Desktop packages | `modules/packages-desktop.nix` | pc, fx516, notebook |  |
| Desktop-Only Modules | Sound / audio | `modules/sound.nix` | pc, fx516, notebook |  |
| Desktop-Only Modules | Wayland | `modules/wayland.nix` | pc, fx516, notebook |  |
| Desktop-Only Modules | Niri scrollable-tiling compositor, trial alongside sway: | `modules/niri.nix` | pc | docs/routes-notes.md#niri |
| Desktop-Only Modules | Greeter (ly + sway wayland-session entry). `DesktopNames=sway;X-NIXOS-SYSTEMD-AWARE` is load-bearing: | `modules/greeter.nix` | pc, fx516, notebook | docs/routes-notes.md#greeter |
| Desktop-Only Modules | NFS mounts (`/home/drive` from `server:/drive`; `/hdd4tb/torrents` from `server:/hdd4tb/torrents`) | `modules/nfs.nix` | pc, fx516, notebook |  |
| Desktop-Only Modules | Thunar file manager | `modules/thunar.nix` | pc, fx516, notebook |  |
| Desktop-Only Modules | JetBrains IDE wrapper module | `modules/ide/module.nix` | pc, notebook |  |
| Desktop-Only Modules | Work secrets (agent tokens): | `modules/work-mount.nix` | pc, notebook |  |
| PC-Specific Modules | PC host config entry point | `hosts/configuration.nix` | pc |  |
| PC-Specific Modules | Home drive mount | `modules/home-drive.nix` | pc |  |
| PC-Specific Modules | `/drive` -> `/home/drive` symlink for offloaded build jobs, isolated for easy removal after the project ends | `modules/drive-link.nix` | pc |  |
| PC-Specific Modules | AMD GPU (Radeon) | `modules/radeon.nix` | pc |  |
| PC-Specific Modules | AMD GPU (extra) | `modules/amd/default.nix` | pc |  |
| PC-Specific Modules | UxPlay (AirPlay) | `modules/uxplay.nix` | pc |  |
| PC-Specific Modules | Virtual machines / libvirt | `modules/vm.nix` | pc | (disabled) |
| PC-Specific Modules | Kernel (CachyOS) | `modules/kernel-cachyos.nix` | pc |  |
| PC-Specific Modules | Swap: zram hot tier only | `modules/swap.nix` | pc, server | docs/routes-notes.md#swap |
| PC-Specific Modules | Early OOM killing: | `modules/oom.nix` | pc, server | docs/routes-notes.md#oom |
| PC-Specific Modules | `/tmp` and the nix build directory in RAM | `modules/tmpfs.nix` | pc, server | docs/routes-notes.md#tmpfs |
| PC-Specific Modules | Steam | `modules/steam.nix` | pc, notebook |  |
| PC-Specific Modules | Esync | `modules/esync.nix` | pc |  |
| PC-Specific Modules | ADB (Android Debug Bridge) | `modules/adb.nix` | pc, notebook |  |
| PC-Specific Modules | Bluetooth | `modules/bluetooth.nix` | pc, notebook |  |
| PC-Specific Modules | Gamepad support | `modules/gamepad.nix` | pc |  |
| PC-Specific Modules | Vial (keyboard) | `modules/vial.nix` | pc |  |
| PC-Specific Modules | K3s | `modules/k3s.nix` | pc |  |
| PC-Specific Modules | Firefox | `modules/firefox.nix` | pc |  |
| PC-Specific Modules | Syncthing (pc) | `modules/syncthing/pc.nix` | pc |  |
| PC-Specific Modules | Syncthing common module | `modules/syncthing/default.nix` | pc, notebook, server |  |
| PC-Specific Modules | Syncthing device IDs | `modules/syncthing/devices.nix` | pc, notebook, server |  |
| PC-Specific Modules | Monitor values | `hosts/configuration.nix` | pc | (pc) |
| PC-Specific Modules | Hardware (pc) | `hosts/hardware-pc.nix` | pc |  |
| PC-Specific Modules | GPU profile (LACT: undervolt, fan curve, power profile) | `hosts/lact-pc.yaml` | pc | Deployed to `/etc/lact/config.yaml` via `environment.etc`; GUI cannot save while it is a store symlink |
| PC-Specific Modules | RGB lighting (OpenRGB): | `pkgs/openrgb-profile.nix` | pc | docs/routes-notes.md#openrgb-profile |
| PC-Specific Modules | Keyboard backlight | `pkgs/keychron-backlight.nix` | pc | docs/routes-notes.md#keychron-backlight |
| PC-Specific Modules | Hardware watchdog | `hosts/configuration.nix` | pc | (sp5100_tco); armed by `systemd.settings.Manager.RuntimeWatchdogSec`; self-reboot 60s after a hang |
| PC-Specific Modules | belphegor, gnupg, dconf | `hosts/configuration.nix` | pc |  |
| FX516-Specific Modules | FX516 host config entry point | `hosts/configuration-fx516.nix` | fx516 |  |
| FX516-Specific Modules | Kernel (Zen) | `modules/kernel-zen.nix` | fx516, notebook |  |
| FX516-Specific Modules | NVIDIA GPU | `modules/nvidia/default.nix` | fx516 |  |
| FX516-Specific Modules | NVIDIA Prime | `modules/nvidia/prime.nix` | fx516 |  |
| FX516-Specific Modules | Thunderbolt | `modules/thunderbolt.nix` | fx516, notebook |  |
| FX516-Specific Modules | Monitor values | `hosts/configuration-fx516.nix` | fx516 | (fx516) |
| FX516-Specific Modules | Hardware (fx516) | `hosts/hardware-fx516.nix` | fx516 |  |
| Notebook-Specific Modules | Notebook host config entry point | `hosts/configuration-notebook.nix` | notebook |  |
| Notebook-Specific Modules | Battery management | `modules/battery.nix` | notebook |  |
| Notebook-Specific Modules | Hibernation | `modules/hibernation.nix` | notebook |  |
| Notebook-Specific Modules | ADB | `modules/adb.nix` | pc, notebook |  |
| Notebook-Specific Modules | Syncthing (notebook) | `modules/syncthing/notebook.nix` | notebook |  |
| Notebook-Specific Modules | IDE host options | `hosts/configuration-notebook.nix` | notebook | (notebook) |
| Notebook-Specific Modules | Monitor values | `hosts/configuration-notebook.nix` | notebook | (notebook) |
| Notebook-Specific Modules | Hardware (notebook) | `hosts/hardware-notebook.nix` | notebook |  |
| Server-Specific Modules | Server host config entry point | `hosts/configuration-server.nix` | server |  |
| Server-Specific Modules | Server packages | `modules/packages-server.nix` | pc, fx516, notebook, server |  |
| Server-Specific Modules | Nginx; aborted HTTP/2 downloads, KTLS; fail2ban nginx jails | `modules/nginx.nix`, `docs/nginx.md` | server | docs/routes-notes.md#nginx |
| Server-Specific Modules | Binary cache | `modules/harmonia.nix`, `docs/nginx.md` | server | (harmonia) |
| Server-Specific Modules | ZeroSSL ACME for nginx | `modules/zerossl.nix` | server | docs/routes-notes.md#zerossl |
| Server-Specific Modules | LiteLLM | `modules/litellm/default.nix` | server | docs/routes-notes.md#litellm |
| Server-Specific Modules | Drive mounts | `modules/drive.nix`, `docs/zfs-pool.md` | server | docs/routes-notes.md#drive |
| Server-Specific Modules | Kernel (mainline, ZFS-compatible) | `modules/kernel-server.nix` | server | docs/routes-notes.md#kernel-server |
| Server-Specific Modules | ZFS support (kernel module, hostId; scrub and trim timers on for hosts with a pool; mirror read bias toward flash) | `modules/zfs.nix` | server | docs/routes-notes.md#zfs |
| Server-Specific Modules | Grafana | `modules/grafana.nix`, `docs/monitoring.md` | server | docs/routes-notes.md#grafana |
| Server-Specific Modules | Prometheus, Loki, Alloy | `modules/grafana.nix` | server | docs/routes-notes.md#grafana-2 |
| Server-Specific Modules | Prometheus TSDB storage | `modules/grafana.nix`, `modules/drive.nix`, `docs/monitoring.md` | server | docs/routes-notes.md#grafana-3 |
| Server-Specific Modules | SMARTctl exporter by-id device autodiscovery | `modules/grafana.nix`, `docs/smartctl-exporter.md` | server | docs/routes-notes.md#grafana-4 |
| Server-Specific Modules | Grafana monitoring aggregator | `modules/monitoring/default.nix` | server | (imports shared contact points + per-service alert files) |
| Server-Specific Modules | node_exporter systemd restart counts, textfile collector directory, process exporter | `modules/grafana.nix`, `docs/monitoring.md` | server | docs/routes-notes.md#grafana-5 |
| Server-Specific Modules | Docker container-state textfile exporter | `modules/monitoring/container-state.nix`, `docs/monitoring.md` | server | docs/routes-notes.md#container-state |
| Server-Specific Modules | OpenWrt and murmur SSH metrics collector, minute timer and Grafana dashboard | `modules/monitoring/openwrt-murmur.nix`, `modules/monitoring/openwrt-murmur-collector.py`, `modules/monitoring/dashboards/openwrt-murmur.json`, `docs/monitoring.md` | server |  |
| Server-Specific Modules | Grafana alert: failures | `modules/monitoring/failures.nix`, `docs/monitoring.md` | server |  |
| Server-Specific Modules | Grafana notification channels | `modules/monitoring/contact-points.nix` | server | docs/routes-notes.md#contact-points |
| Server-Specific Modules | Grafana alert: | `modules/monitoring/tidal-syncer.nix` | server | tidal-syncer TIDAL re-login required (Prometheus metric alert) |
| Server-Specific Modules | Grafana alert: storage | `modules/monitoring/storage.nix`, `docs/zfs-pool.md` | server |  |
| Server-Specific Modules | Grafana alerts: OpenCode Go price sync | `modules/monitoring/litellm.nix` | server | docs/routes-notes.md#litellm-2 |
| Server-Specific Modules | tidal-syncer daemon | `modules/tidal-syncer.nix` | server | (native service: config, agenix secret, Prometheus scrape + Grafana dashboard) |
| Server-Specific Modules | Music Assistant server | `modules/music-assistant.nix`, `docs/music-assistant.md` | server | docs/routes-notes.md#music-assistant |
| Server-Specific Modules | FRP (Fast Reverse Proxy); fail2ban jail `frp-auth` and its filter | `modules/frp.nix` | server | docs/routes-notes.md#frp |
| Server-Specific Modules | fail2ban: sshd blindness, filter traps, port scoping, nftables ban backend | `modules/network/firewall.nix`, `modules/frp.nix`, `docs/fail2ban.md` | pc, fx516, notebook, server | docs/routes-notes.md#firewall-2 |
| Server-Specific Modules | Grafana alert: | `modules/monitoring/frp.nix` | server | docs/routes-notes.md#frp-2 |
| Server-Specific Modules | Syncthing (server) | `modules/syncthing/server.nix` | server |  |
| Server-Specific Modules | NVIDIA GT 210 | `modules/nvidia/gt210.nix` | server |  |
| Server-Specific Modules | Vaultwarden | `modules/vaultwarden.nix` | server |  |
| Server-Specific Modules | qBittorrent (download path and mount guard) | `modules/qbittorrent.nix` | server | docs/routes-notes.md#qbittorrent |
| Server-Specific Modules | AmneziaWG | `modules/awg/default.nix` | server |  |
| Server-Specific Modules | AmneziaWG compose stack | `modules/awg/compose.nix` | server |  |
| Server-Specific Modules | GitHub triage / fix bot | `modules/buer/default.nix`, `modules/buer/docker-compose.yml`, `docs/buer.md` | server | docs/routes-notes.md#buer |
| Server-Specific Modules | Buer Go/Nix toolchain and publication policy | `modules/buer/default.nix`, `modules/buer/docker-compose.yml`, `modules/buer/agent-AGENTS.md`, `modules/buer/empty-pr-body.patch`, `docs/buer.md` | server |  |
| Server-Specific Modules | Network (server) | `modules/network/default.nix` | pc, fx516, notebook, server |  |
| Server-Specific Modules | Recursive validating DNS resolver | `modules/unbound.nix` | server |  |
| Server-Specific Modules | Encrypted DNS: | `modules/unbound.nix` | server | docs/routes-notes.md#unbound |
| Server-Specific Modules | DNS query logging and outbound rate limit | `modules/unbound.nix` | server | docs/routes-notes.md#unbound-2 |
| Server-Specific Modules | Ad and tracker filtering, blocklist refresh | `modules/unbound.nix` | server | docs/routes-notes.md#unbound-3 |
| Server-Specific Modules | Router-side DNS hijack, adblock-fast removal | `docs/dns-clients.md` | server | docs/routes-notes.md#dns-clients |
| Server-Specific Modules | ifconfig.io container behind `ip.labile.cc` | `modules/ifconfig.nix` | server | docs/routes-notes.md#ifconfig |
| Server-Specific Modules | ChromaDB vector database service | `modules/chromadb.nix` | server | docs/routes-notes.md#chromadb |
| Server-Specific Modules | Hardware (server) | `hosts/hardware-server.nix` | server |  |
| Home Manager Modules | HM entry point | `home-manager/modules/default.nix` | pc, fx516, notebook, server |  |
| Home Manager Modules | Sway window manager | `home-manager/modules/sway.nix` | pc, fx516, notebook, server | docs/routes-notes.md#sway |
| Home Manager Modules | Waybar status bar. `sway/workspaces` and `sway/language` only work under sway, so both module choices | `home-manager/modules/waybar.nix` | pc, fx516, notebook, server | docs/routes-notes.md#waybar |
| Home Manager Modules | Wofi launcher. The stylix rofi target is disabled there too: | `home-manager/modules/wofi.nix` | pc, fx516, notebook, server |  |
| Home Manager Modules | Mako notifications | `home-manager/modules/mako.nix` | pc, fx516, notebook, server |  |
| Home Manager Modules | Niri compositor config | `home-manager/modules/niri.nix` | pc, fx516, notebook, server | docs/routes-notes.md#niri-2 |
| Home Manager Modules | Git user config | `home-manager/modules/git.nix` | pc, fx516, notebook, server |  |
| Home Manager Modules | Foot terminal | `home-manager/modules/foot.nix` | pc, fx516, notebook, server |  |
| Home Manager Modules | Alacritty terminal | `home-manager/modules/alacritty.nix` | pc, fx516, notebook, server |  |
| Home Manager Modules | Ghostty terminal | `home-manager/modules/ghostty.nix` | pc, fx516, notebook, server | docs/routes-notes.md#ghostty |
| Home Manager Modules | Zellij multiplexer | `home-manager/modules/zellij.nix` | pc, fx516, notebook, server | (parallel to tmux; direct Ctrl+a/d/x chords) |
| Home Manager Modules | SSH user config | `home-manager/modules/ssh.nix` | pc, fx516, notebook, server |  |
| Home Manager Modules | MIME type associations | `home-manager/modules/mimeapps.nix` | pc, fx516, notebook, server |  |
| Home Manager Modules | mpv media player | `home-manager/modules/mpv.nix` | pc, fx516, notebook, server |  |
| Home Manager Modules | EasyEffects audio | `home-manager/modules/easyeffects.nix` | pc, fx516, notebook, server |  |
| Home Manager Modules | Thunar (user config) | `home-manager/modules/thunar.nix` | pc, fx516, notebook, server |  |
| Home Manager Modules | yt-dlp | `home-manager/modules/yt-dlp.nix` | pc, fx516, notebook, server |  |
| Home Manager Modules | XDG user dirs | `home-manager/modules/xdg.nix` | pc, fx516, notebook, server |  |
| Cross-Cutting Tasks | Add package from flake input | `flake.nix`, `overlays.nix`, `modules/packages.nix`, `packages-desktop.nix`, `packages-server.nix` | pc, fx516, notebook, server |  |
| Cross-Cutting Tasks | Add local package | `pkgs/<name>.nix`, `overlays.nix`, `modules/packages.nix`, `packages-desktop.nix`, `packages-server.nix` | pc, fx516, notebook, server |  |
| Cross-Cutting Tasks | Push store paths to the binary cache | `modules/cache-push.nix`, `settings.nix`, `modules/packages.nix` | pc, fx516, notebook, server |  |
| Cross-Cutting Tasks | Add AGenix secret | `secrets/<name>.age` | pc, fx516, notebook, server | `secrets/<name>.age` (encrypt); host config (add `age.secrets.<name>`) |
| Cross-Cutting Tasks | Add new NixOS module | `modules/<name>.nix`, `modules/base.nix` | pc, fx516, notebook, server | `modules/<name>.nix` (create); `modules/base.nix` or per-host config (add import) |
| Cross-Cutting Tasks | Add a Grafana alert for a service | `modules/monitoring/<service>.nix`, `modules/monitoring/default.nix` | server |  |
| Cross-Cutting Tasks | Add new HM module | `home-manager/modules/<name>.nix`, `home-manager/modules/default.nix` | pc, fx516, notebook, server | `home-manager/modules/<name>.nix` (create); `home-manager/modules/default.nix` (add import) |
| Code indexer wiring | Package overlay | `overlays.nix` | pc, fx516, notebook, server | `index-repo = inputs.index-repo.packages.${system}.default` (→ `pkgs.index-repo`) |
| Code indexer wiring | Oh-my-pi register hook | `~/.omp/agent/extensions/repo-register.js` | pc, fx516, notebook, server |  |
| Code indexer wiring | Jcode register hook | `~/.jcode/config.toml` | pc, fx516, notebook, server |  |
| Optional / Currently Unimported Modules | Virtual machines / libvirt | `modules/vm.nix` | pc | Commented in `hosts/configuration.nix` |
| Other Files | Flake inputs, outputs, host wiring | `flake.nix` | pc, fx516, notebook, server |  |
| Other Files | Per-language dev shells | `modules/shell/devshells.nix` | pc, fx516, notebook, server | (`nix develop dev#<lang>`); imported by `flake.nix` outputs |
| Other Files | Custom package overlays | `overlays.nix` | pc, fx516, notebook, server |  |
| Other Files | Common settings | `settings.nix` | pc, fx516, notebook, server | docs/routes-notes.md#settings |
| Other Files | Convenience targets: | `Makefile` | pc, fx516, notebook, server | `switch`, `boot`, `upgrade`, `fmt`, `cleanup`, `optimise` |
| Other Files | Project-scoped MCP servers for this repo; edited here directly, not generated by the omp module | `.omp/mcp.json` | pc, fx516, notebook, server | (`modules/omp/default.nix`) |
| Other Files | Project-scoped MCP servers for maki in this repo | `.maki/mcp.toml` | pc, fx516, notebook, server |  |
| Other Files | The `nix-control` MCP server, split by concern: | `.omp/nix-control-mcp/*.py` | pc, fx516, notebook, server |  |
| Other Files | Project skills live under `.omp/skills/`, loaded by omp's native skill provider | `.omp/skills/nix-routing/SKILL.md` | pc, fx516, notebook, server |  |
| System Modules | OMP shell grep gate and declarative skill cleanup (all OMP hosts) | `modules/omp/extensions/grep-gate.ts`, `modules/omp/install.nix`, `modules/omp/packages.nix`, `modules/omp/settings/skills.nix`, `modules/omp/skills-prune.sh` | pc, fx516, notebook, server |  |
| Code indexer wiring | Indexer system service and ChromaDB endpoint | `modules/omp/index-repo.nix`, `modules/chromadb.nix` | pc, fx516, notebook, server | docs/routes-notes.md#index-repo |
| Other Files | Routing registry read by the nix-control route tool | `docs/routes.toml` | pc, fx516, notebook, server |  |
| Other Files | Generated route index for humans and for a failed MCP server | `docs/routes.md` | pc, fx516, notebook, server |  |
| Other Files | Longer route knowledge referenced by `doc` fields | `docs/routes-notes.md` | pc, fx516, notebook, server | One `## <anchor>` section per route that outgrew a one-line note; the registry links the exact anchor. |
| Other Files | Routing registry regression checks | `.omp/nix-control-mcp/routes_test.py` | pc, fx516, notebook, server |  |
