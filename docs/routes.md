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
| System Modules | Systemd manager settings (stop timeout, default OOM policy) | `modules/systemd.nix` | pc, fx516, notebook, server |  |
| System Modules | Journald logging | `modules/journald.nix` | pc, fx516, notebook, server |  |
| System Modules | ZSH configuration | `modules/shell.nix` | pc, fx516, notebook, server |  |
| System Modules | tmux terminal multiplexer (prefix `Ctrl+a`) | `modules/tmux.nix` | pc, fx516, notebook, server |  |
| System Modules | Terminal switch | `modules/terminal.nix` | pc, fx516, notebook, server | docs/routes-notes.md#terminal |
| System Modules | Display monitors (declarations) | `modules/monitors.nix` | pc, fx516, notebook, server | Values set in per-host config |
| System Modules | Docker daemon | `modules/docker.nix` | pc, fx516, notebook, server |  |
| System Modules | Polkit rules | `modules/polkit.nix` | pc, fx516, notebook, server |  |
| System Modules | NVMe drive tuning | `modules/nvme.nix`, `docs/nvme.md` | pc, fx516, notebook, server | docs/routes-notes.md#nvme |
| System Modules | GNOME keyring | `modules/keyring.nix` | pc, fx516, notebook, server |  |
| System Modules | Locale, timezone | `modules/locale.nix` | pc, fx516, notebook, server |  |
| System Modules | User accounts, shell aliases, Home Manager wiring | `modules/users.nix` | pc, fx516, notebook, server |  |
| System Modules | LLM gateway and provider API keys for omp/jcode hosts (agenix `llm-labile-env` holds the scoped LiteLLM key behind omp's `llm-labile` provider in | `modules/opencode-secrets.nix` | pc, fx516, notebook, server | docs/routes-notes.md#opencode-secrets |
| System Modules | Environment variables | `modules/env.nix` | pc, fx516, notebook, server |  |
| System Modules | Network entry point | `modules/network/default.nix` | pc, fx516, notebook, server | Imports DNS, firewall, hosts, proxy sub-modules |
| System Modules | Network DNS | `modules/network/dns.nix` | pc, fx516, notebook, server | Imported by `modules/network/default.nix` |
| System Modules | Network firewall | `modules/network/firewall.nix` | pc, fx516, notebook, server | docs/routes-notes.md#firewall |
| System Modules | Network hosts injection | `modules/network/hosts.nix` | pc, fx516, notebook, server | Imported by `modules/network/default.nix` |
| System Modules | Network proxy | `modules/network/proxy.nix` | pc, fx516, notebook, server | Imported by `modules/network/default.nix` |
| System Modules | System packages (all hosts) | `modules/packages.nix` | pc, fx516, notebook, server |  |
| System Modules | btop user config (full default + show swap, all hosts) | `modules/btop.nix` | pc, fx516, notebook, server | Deploys `~/.config/btop/btop.conf` via `systemd.tmpfiles` store symlink; imported + enabled per-host |
| System Modules | OpenSSH daemon | `modules/ssh.nix` | pc, fx516, notebook, server |  |
| System Modules | Remote Nix builders | `modules/builders.nix` | pc, fx516, notebook, server |  |
| System Modules | Sway hotkeys | `modules/hotkeys.nix` | pc, fx516, notebook, server |  |
| System Modules | nix-search-tv | `modules/nix-search-tv.nix` | pc, fx516, notebook, server |  |
| System Modules | nix-ld dynamic loader (FHS shim) | `modules/nix-ld.nix` | pc, fx516, notebook, server | Libraries for prebuilt Python wheels / ML runtimes |
| System Modules | Neovim (nixvim) entry point | `modules/nixvim/default.nix` | pc, fx516, notebook, server | Imports plugin and keymap sub-modules |
| System Modules | Neovim plugins | `modules/nixvim/plugins.nix` | pc, fx516, notebook, server | Imports/uses plugin component files in `modules/nixvim/` |
| System Modules | Neovim keymaps | `modules/nixvim/keymaps.nix` | pc, fx516, notebook, server | Imported by `modules/nixvim/default.nix` |
| System Modules | Neovim completion | `modules/nixvim/cmp.nix`, `modules/nixvim/blink.nix` | pc, fx516, notebook, server | Plugin component files |
| System Modules | Neovim LSP/debug/format/search | `modules/nixvim/lsp.nix`, `modules/nixvim/dap.nix`, `modules/nixvim/conform.nix`, `modules/nixvim/telescope.nix` | pc, fx516, notebook, server | Plugin component files |
| System Modules | Neovim UI tabs | `modules/nixvim/barbar.nix` | pc, fx516, notebook, server | Plugin component file |
| System Modules | Stylix theming | `modules/stylix.nix` | pc, fx516, notebook, server |  |
| System Modules | Flake registry `dev` (global dev shell access) | `modules/shell/registry.nix` | pc, fx516, notebook, server | Added to `commonModules` in `flake.nix` |
| System Modules | Oh My Pi (omp) coding agent | `modules/omp/default.nix` | pc, fx516, notebook, server | docs/routes-notes.md#omp |
| System Modules | OMP shell grep gate and declarative skill cleanup (all OMP hosts) | `modules/omp/install.nix`, `modules/omp/packages.nix`, `modules/omp/settings/skills.nix` | pc, fx516, notebook, server |  |
| System Modules | Oh My Pi input, module and package overlay | `flake.nix`, `flake.lock`, `overlays.nix` | pc, fx516, notebook, server | docs/routes-notes.md#flake |
| System Modules | Jcode coding agent | `modules/jcode/default.nix` | pc, fx516, notebook, server | docs/routes-notes.md#jcode |
| System Modules | Local FreeDeepseekAPI profile for jcode (DeepSeek-V4.1-Flash web proxy: provider `deepseek-web`, four composer-switch model ids, image input | `modules/jcode/deepseek-web.nix`, `modules/jcode/deepseek-session.py` | pc, fx516, notebook, server | docs/routes-notes.md#deepseek-web |
| System Modules | OpenCode Go `space-bunny-free` capability override for jcode (provider `opencode-go-bunny`: 1M context, text+image input, reasoning effort `high` by default) | `modules/jcode/space-bunny.nix` | pc, fx516, notebook, server | docs/routes-notes.md#space-bunny |
| System Modules | Maki coding agent (pc, server, notebook) | `modules/maki/default.nix` | pc, fx516, notebook, server | docs/routes-notes.md#maki |
| System Modules | Yazi file manager (all hosts, single implementation; the Home Manager module is gone) | `modules/yazi.nix` | pc, fx516, notebook, server | docs/routes-notes.md#yazi |
| Desktop-Only Modules | Desktop packages | `modules/packages-desktop.nix` | pc, fx516, notebook | pc, fx516, notebook |
| Desktop-Only Modules | Sound / audio | `modules/sound.nix` | pc, fx516, notebook | pc, fx516, notebook |
| Desktop-Only Modules | Wayland | `modules/wayland.nix` | pc, fx516, notebook | pc, fx516, notebook |
| Desktop-Only Modules | Niri scrollable-tiling compositor, trial alongside sway: `programs.niri.enable` only (package, `niri.desktop` session for ly, niri's own systemd user units | `modules/niri.nix` | pc |  |
| Desktop-Only Modules | Greeter (ly + sway wayland-session entry). `DesktopNames=sway;X-NIXOS-SYSTEMD-AWARE` is load-bearing: without the second name the NixOS session wrapper starts | `modules/greeter.nix` | pc, fx516, notebook | docs/routes-notes.md#greeter |
| Desktop-Only Modules | NFS mounts (`/home/drive` from `server:/drive`; `/hdd4tb/torrents` from `server:/hdd4tb/torrents`) | `modules/nfs.nix` | pc, fx516, notebook | pc, fx516, notebook |
| Desktop-Only Modules | Thunar file manager | `modules/thunar.nix` | pc, fx516, notebook | pc, fx516, notebook |
| Desktop-Only Modules | JetBrains IDE wrapper module | `modules/ide/module.nix` | pc, notebook | flake common module; enabled by host `ide.*` options on pc/notebook |
| Desktop-Only Modules | Work secrets (agent tokens): jira/gitlab/grafana + `portainer-mcp` (Portainer URL + API key) + `google-docs-mcp` | `modules/work-mount.nix` | pc, notebook |  |
| PC-Specific Modules | PC host config entry point | `hosts/configuration.nix` | pc |  |
| PC-Specific Modules | Home drive mount | `modules/home-drive.nix` | pc |  |
| PC-Specific Modules | `/drive` -> `/home/drive` symlink for offloaded build jobs, isolated for easy removal after the project ends | `modules/drive-link.nix` | pc |  |
| PC-Specific Modules | AMD GPU (Radeon) | `modules/radeon.nix` | pc |  |
| PC-Specific Modules | AMD GPU (extra) | `modules/amd/default.nix` | pc |  |
| PC-Specific Modules | UxPlay (AirPlay) | `modules/uxplay.nix` | pc |  |
| PC-Specific Modules | Virtual machines / libvirt (disabled) | `modules/vm.nix` | pc |  |
| PC-Specific Modules | Kernel (CachyOS) | `modules/kernel-cachyos.nix` | pc |  |
| PC-Specific Modules | Swap: zram hot tier only (`server`; NVMe overflow tier removed temporarily), `vm` sysctls (imported by `hosts/configuration.nix` and `hosts/configuration-server.nix`) | `modules/swap.nix` | pc, server |  |
| PC-Specific Modules | Early OOM killing: `earlyoom` prefers killing expendable build tools (compilers/linkers) over the tmux/omp session before kernel OOM-thrash triggers `DefaultOOMPolicy=stop` | `modules/oom.nix` | pc, server |  |
| PC-Specific Modules | `/tmp` and the nix build directory in RAM (imported by `hosts/configuration.nix` and `hosts/configuration-server.nix`) | `modules/tmpfs.nix` | pc, server |  |
| PC-Specific Modules | Steam | `modules/steam.nix` | pc, notebook |  |
| PC-Specific Modules | Esync | `modules/esync.nix` | pc |  |
| PC-Specific Modules | ADB (Android Debug Bridge) | `modules/adb.nix` | pc, notebook |  |
| PC-Specific Modules | Bluetooth | `modules/bluetooth.nix` | pc, notebook |  |
| PC-Specific Modules | Gamepad support | `modules/gamepad.nix` | pc |  |
| PC-Specific Modules | Vial (keyboard) | `modules/vial.nix` | pc |  |
| PC-Specific Modules | K3s | `modules/k3s.nix` | pc |  |
| PC-Specific Modules | Firefox | `modules/firefox.nix` | pc |  |
| PC-Specific Modules | Syncthing (pc) | `modules/syncthing/pc.nix` | pc |  |
| PC-Specific Modules | Syncthing common module | `modules/syncthing/default.nix` | pc, server |  |
| PC-Specific Modules | Syncthing device IDs | `modules/syncthing/devices.nix` | pc, server |  |
| PC-Specific Modules | Monitor values (pc) | `hosts/configuration.nix` | pc |  |
| PC-Specific Modules | Hardware (pc) | `hosts/hardware-pc.nix` | pc |  |
| PC-Specific Modules | GPU profile (LACT: undervolt, fan curve, power profile) | `hosts/lact-pc.yaml` | pc |  |
| PC-Specific Modules | RGB lighting (OpenRGB): device profiles + blanking | `pkgs/openrgb-profile.nix` | pc |  |
| PC-Specific Modules | Keyboard backlight (Keychron Q6 Max) | `pkgs/keychron-backlight.nix` | pc |  |
| PC-Specific Modules | Hardware watchdog (sp5100_tco) | `hosts/configuration.nix` | pc |  |
| PC-Specific Modules | belphegor, gnupg, dconf | `hosts/configuration.nix` | pc |  |
| FX516-Specific Modules | FX516 host config entry point | `hosts/configuration-fx516.nix` | fx516 |  |
| FX516-Specific Modules | Kernel (Zen) | `modules/kernel-zen.nix` | fx516, notebook |  |
| FX516-Specific Modules | NVIDIA GPU | `modules/nvidia/default.nix` | fx516 |  |
| FX516-Specific Modules | NVIDIA Prime | `modules/nvidia/prime.nix` | fx516 |  |
| FX516-Specific Modules | Thunderbolt | `modules/thunderbolt.nix` | fx516, notebook |  |
| FX516-Specific Modules | Monitor values (fx516) | `hosts/configuration-fx516.nix` | fx516 |  |
| FX516-Specific Modules | Hardware (fx516) | `hosts/hardware-fx516.nix` | fx516 |  |
| Notebook-Specific Modules | Notebook host config entry point | `hosts/configuration-notebook.nix` | notebook |  |
| Notebook-Specific Modules | Battery management | `modules/battery.nix` | notebook |  |
| Notebook-Specific Modules | Hibernation | `modules/hibernation.nix` | notebook |  |
| Notebook-Specific Modules | Syncthing (notebook) | `modules/syncthing/notebook.nix` | notebook |  |
| Notebook-Specific Modules | IDE host options (notebook) | `hosts/configuration-notebook.nix` | notebook |  |
| Notebook-Specific Modules | Monitor values (notebook) | `hosts/configuration-notebook.nix` | notebook |  |
| Notebook-Specific Modules | Hardware (notebook) | `hosts/hardware-notebook.nix` | notebook |  |
| Server-Specific Modules | Server host config entry point | `hosts/configuration-server.nix` | server |  |
| Server-Specific Modules | Server packages | `modules/packages-server.nix` | server |  |
| Server-Specific Modules | Nginx; aborted HTTP/2 downloads, KTLS; fail2ban nginx jails (`nginx-botsearch`, `nginx-bad-request`, `nginx-scan-404`, `nginx-secret-probe`) and their filters | `modules/nginx.nix`, `docs/nginx.md` | server |  |
| Server-Specific Modules | Binary cache (harmonia) | `modules/harmonia.nix`, `docs/nginx.md` | server |  |
| Server-Specific Modules | ZeroSSL ACME for nginx | `modules/zerossl.nix` | server |  |
| Server-Specific Modules | LiteLLM | `modules/litellm/default.nix` | server |  |
| Server-Specific Modules | Drive mounts (`/drive` ZFS pool `data`, mirror of a 2 TB SATA SSD + a 2 TB SMR HDD; `/hdd4tb` 4 TB SATA HDD hosting `/hdd4tb/torrents` and the Prometheus TSDB) | `modules/drive.nix`, `docs/zfs-pool.md` | server |  |
| Server-Specific Modules | Kernel (mainline, ZFS-compatible) | `modules/kernel-server.nix` | server, pc |  |
| Server-Specific Modules | ZFS support (kernel module, hostId; scrub and trim timers on for hosts with a pool; mirror read bias toward flash) | `modules/zfs.nix` | server |  |
| Server-Specific Modules | Grafana | `modules/grafana.nix`, `docs/monitoring.md` | server |  |
| Server-Specific Modules | Prometheus, Loki, Alloy (ships nginx/angie + docker container + fail2ban logs to Loki) | `modules/grafana.nix` | server |  |
| Server-Specific Modules | Prometheus TSDB storage (bind `/var/lib/prometheus2` from `/hdd4tb/prometheus`, completed one-shot migration, one-year retention) | `modules/grafana.nix`, `modules/drive.nix`, `docs/monitoring.md` | server |  |
| Server-Specific Modules | SMARTctl exporter by-id device autodiscovery (`ExecStart` override, dashboard `group_left` join) | `modules/grafana.nix`, `docs/smartctl-exporter.md` | server |  |
| Server-Specific Modules | Grafana monitoring aggregator (imports shared contact points + per-service alert files) | `modules/monitoring/default.nix` | server |  |
| Server-Specific Modules | node_exporter systemd restart counts, textfile collector directory, process exporter (per-process memory) | `modules/grafana.nix`, `docs/monitoring.md` | server |  |
| Server-Specific Modules | Docker container-state textfile exporter (systemd oneshot + 30s timer, writes `docker_container_*` metrics) | `modules/monitoring/container-state.nix`, `docs/monitoring.md` | server |  |
| Server-Specific Modules | OpenWrt and murmur SSH metrics collector, minute timer and Grafana dashboard | `modules/monitoring/openwrt-murmur.nix`, `modules/monitoring/openwrt-murmur-collector.py`, `modules/monitoring/dashboards/openwrt-murmur.json`, `docs/monitoring.md` | server |  |
| Server-Specific Modules | Grafana alert: failures | `modules/monitoring/failures.nix`, `docs/monitoring.md` | server |  |
| Server-Specific Modules | Grafana notification channels (two Telegram contact points + agenix secret) | `modules/monitoring/contact-points.nix` | server |  |
| Server-Specific Modules | Grafana alert: tidal-syncer TIDAL re-login required (Prometheus metric alert) | `modules/monitoring/tidal-syncer.nix` | server |  |
| Server-Specific Modules | Grafana alert: storage | `modules/monitoring/storage.nix`, `docs/zfs-pool.md` | server |  |
| Server-Specific Modules | Grafana alerts: OpenCode Go price sync | `modules/monitoring/litellm.nix` | server | the sync refused to apply the table, a rate changed, or nothing succeeded for three days |
| Server-Specific Modules | tidal-syncer daemon (native service: config, agenix secret, Prometheus scrape + Grafana dashboard) | `modules/tidal-syncer.nix` | server |  |
| Server-Specific Modules | Music Assistant server (player UI on 8095, built-in Snapcast server 1704/1705, stream 8097) | `modules/music-assistant.nix`, `docs/music-assistant.md` | server |  |
| Server-Specific Modules | FRP (Fast Reverse Proxy); fail2ban jail `frp-auth` and its filter | `modules/frp.nix` | server |  |
| Server-Specific Modules | fail2ban: sshd blindness, filter traps, port scoping, nftables ban backend | `modules/network/firewall.nix`, `modules/frp.nix`, `docs/fail2ban.md` | server |  |
| Server-Specific Modules | Grafana alert: frp tunnel connection lost (Loki log alert on frp-server journal) | `modules/monitoring/frp.nix` | server |  |
| Server-Specific Modules | Syncthing (server) | `modules/syncthing/server.nix` | server |  |
| Server-Specific Modules | NVIDIA GT 210 | `modules/nvidia/gt210.nix` | server |  |
| Server-Specific Modules | Vaultwarden | `modules/vaultwarden.nix` | server |  |
| Server-Specific Modules | qBittorrent (download path and mount guard) | `modules/qbittorrent.nix` | server |  |
| Server-Specific Modules | AmneziaWG | `modules/awg/default.nix` | server |  |
| Server-Specific Modules | AmneziaWG compose stack | `modules/awg/compose.nix` | server |  |
| Server-Specific Modules | GitHub triage / fix bot (upstream robomp in docker compose) | `modules/buer/default.nix`, `modules/buer/docker-compose.yml`, `docs/buer.md` | server |  |
| Server-Specific Modules | Buer Go/Nix toolchain and publication policy | `modules/buer/default.nix`, `modules/buer/docker-compose.yml`, `modules/buer/agent-AGENTS.md`, `modules/buer/empty-pr-body.patch`, `docs/buer.md` | server |  |
| Server-Specific Modules | Network (server) | `modules/network/default.nix` | server |  |
| Server-Specific Modules | Recursive validating DNS resolver (unbound, RFC 8806 local root zone) | `modules/unbound.nix` | server |  |
| Server-Specific Modules | Encrypted DNS: DoT listener, shared apex TLS cert | `modules/unbound.nix` | server |  |
| Server-Specific Modules | DNS query logging and outbound rate limit | `modules/unbound.nix` | server |  |
| Server-Specific Modules | Ad and tracker filtering, blocklist refresh | `modules/unbound.nix` | server |  |
| Server-Specific Modules | Router-side DNS hijack, adblock-fast removal (not nix-managed) | `docs/dns-clients.md` | server |  |
| Server-Specific Modules | ifconfig.io container behind `ip.labile.cc` | `modules/ifconfig.nix` | server |  |
| Server-Specific Modules | ChromaDB vector database service | `modules/chromadb.nix` | server |  |
| Server-Specific Modules | Hardware (server) | `hosts/hardware-server.nix` | server |  |
| Home Manager Modules | HM entry point | `home-manager/modules/default.nix` | pc, fx516, notebook |  |
| Home Manager Modules | Sway window manager | `home-manager/modules/sway.nix` | pc |  |
| Home Manager Modules | Waybar status bar. `sway/workspaces` and `sway/language` only work under sway, so both module choices (and the `disable-scroll` option | `home-manager/modules/waybar.nix` | pc, fx516, notebook | docs/routes-notes.md#waybar |
| Home Manager Modules | Wofi launcher. The stylix rofi target is disabled there too: rofi is not installed anywhere, and stylix's `modules/rofi/hm.nix` still assigns `programs.rofi.font` | `home-manager/modules/wofi.nix` | pc, fx516, notebook |  |
| Home Manager Modules | Mako notifications | `home-manager/modules/mako.nix` | pc, fx516, notebook |  |
| Home Manager Modules | Niri compositor config (KDL: inputs, monitor layout from `osConfig.monitors`, gaps `2`, thin purple frames via `layout.border`/`layout.focus-ring` width 1 `#7b2cbf`/`#c77dff` | `home-manager/modules/niri.nix` | pc, fx516, notebook | docs/routes-notes.md#niri |
| Home Manager Modules | Git user config | `home-manager/modules/git.nix` | pc, fx516, notebook |  |
| Home Manager Modules | Foot terminal | `home-manager/modules/foot.nix` | pc, fx516, notebook |  |
| Home Manager Modules | Alacritty terminal | `home-manager/modules/alacritty.nix` | pc, fx516, notebook |  |
| Home Manager Modules | Ghostty terminal | `home-manager/modules/ghostty.nix` | pc, fx516, notebook | docs/routes-notes.md#ghostty |
| Home Manager Modules | Zellij multiplexer (parallel to tmux; direct Ctrl+a/d/x chords) | `home-manager/modules/zellij.nix` | pc, fx516, notebook |  |
| Home Manager Modules | SSH user config | `home-manager/modules/ssh.nix` | pc, fx516, notebook |  |
| Home Manager Modules | MIME type associations | `home-manager/modules/mimeapps.nix` | pc, fx516, notebook |  |
| Home Manager Modules | mpv media player | `home-manager/modules/mpv.nix` | pc, fx516, notebook |  |
| Home Manager Modules | EasyEffects audio | `home-manager/modules/easyeffects.nix` | pc, fx516, notebook |  |
| Home Manager Modules | Thunar (user config) | `home-manager/modules/thunar.nix` | pc, fx516, notebook |  |
| Home Manager Modules | yt-dlp | `home-manager/modules/yt-dlp.nix` | pc, fx516, notebook |  |
| Home Manager Modules | XDG user dirs | `home-manager/modules/xdg.nix` | pc, fx516, notebook |  |
| Cross-Cutting Tasks | Add package from flake input | `flake.nix`, `overlays.nix`, `modules/packages.nix`, `packages-desktop.nix`, `packages-server.nix` | pc, fx516, notebook, server |  |
| Cross-Cutting Tasks | Add local package | `pkgs/<name>.nix`, `overlays.nix`, `modules/packages.nix`, `packages-desktop.nix`, `packages-server.nix` | pc, fx516, notebook, server |  |
| Cross-Cutting Tasks | Push store paths to the binary cache | `modules/cache-push.nix`, `settings.nix`, `modules/packages.nix` | pc, fx516, notebook, server |  |
| Cross-Cutting Tasks | Add AGenix secret | `secrets/<name>.age` | pc, fx516, notebook, server |  |
| Cross-Cutting Tasks | Add new NixOS module | `modules/<name>.nix`, `modules/base.nix` | pc, fx516, notebook, server |  |
| Cross-Cutting Tasks | Add a Grafana alert for a service | `modules/monitoring/<service>.nix`, `modules/monitoring/default.nix` | pc, fx516, notebook, server |  |
| Cross-Cutting Tasks | Add new HM module | `home-manager/modules/<name>.nix`, `home-manager/modules/default.nix` | pc, fx516, notebook, server |  |
| Code indexer wiring | Indexer system service and ChromaDB endpoint | `modules/omp/index-repo.nix`, `modules/chromadb.nix` | pc, fx516, notebook, server | docs/routes-notes.md#index-repo |
| Code indexer wiring | Package overlay | `overlays.nix` | pc, fx516, notebook, server | `index-repo = inputs.index-repo.packages.${system}.default` (→ `pkgs.index-repo`) |
| Code indexer wiring | Oh-my-pi register hook | `~/.omp/agent/extensions/repo-register.js` | pc, fx516, notebook, server |  |
| Code indexer wiring | Jcode register hook | `~/.jcode/config.toml` | pc, fx516, notebook, server |  |
| Other Files | Flake inputs, outputs, host wiring | `flake.nix` | pc, fx516, notebook, server |  |
| Other Files | Per-language dev shells (`nix develop dev#<lang>`); imported by `flake.nix` outputs | `modules/shell/devshells.nix` | pc, fx516, notebook, server |  |
| Other Files | Custom package overlays | `overlays.nix` | pc, fx516, notebook, server |  |
| Other Files | Common settings (nix settings, allowed packages), imported by every host through `commonModules`. `pc`/`server`/`notebook` also carry the GitHub API credential that keeps | `settings.nix` | pc, fx516, notebook, server | docs/routes-notes.md#settings |
| Other Files | Convenience targets: `switch`, `boot`, `upgrade`, `fmt`, `cleanup`, `optimise` | `Makefile` | pc, fx516, notebook, server |  |
| Other Files | Project-scoped MCP servers for this repo; edited here directly, not generated by the omp module (`modules/omp/default.nix`) | `.omp/mcp.json` | pc, fx516, notebook, server |  |
| Other Files | Project-scoped MCP servers for maki in this repo (`nix-control`) | `.maki/mcp.toml` | pc, fx516, notebook, server |  |
| Other Files | The `nix-control` MCP server, split by concern: `config` constants, `protocol` JSON-RPC, `text` formatting, `shell` subprocess, `jobs` detached runs, `pane` sudo tmux pane | `.omp/nix-control-mcp/*.py` | pc, fx516, notebook, server |  |
| Other Files | Project skills live under `.omp/skills/`, loaded by omp's native skill provider | `.omp/skills/nix-routing/SKILL.md` | pc, fx516, notebook, server |  |
