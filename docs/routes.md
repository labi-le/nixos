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
| Sudo configuration, NOPASSWD rules | `modules/sudo.nix` | `timestamp_timeout=-1` plus NOPASSWD for exactly two absolute binaries, `nixos-rebuild` and `nix-collect-garbage`, so `make switch` / `make cleanup` never prompt while the login password stays strong; every other command still needs it |
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
| Greeter (ly + sway wayland-session entry). `DesktopNames=sway;X-NIXOS-SYSTEMD-AWARE` is load-bearing: without the second name the NixOS session wrapper starts `nixos-fake-graphical-session.target`, which reaches `graphical-session.target` before sway exports `WAYLAND_DISPLAY`, so every `WantedBy=graphical-session.target` user unit (belphegor, easyeffects, polkit-gnome) is skipped or crashes on a missing display | `modules/greeter.nix` | pc, fx516, notebook |
| NFS mounts | `modules/nfs.nix` | pc, fx516, notebook |
| Thunar file manager | `modules/thunar.nix` | pc, fx516, notebook |
| JetBrains IDE wrapper module | `modules/ide/module.nix` | flake common module; enabled by host `ide.*` options on pc/notebook |
| Work secrets (agent tokens): opencode jira/gitlab/grafana + `portainer-mcp` (Portainer URL + API key; consumed by a project-scoped `.omp/mcp.json`, not by the omp HM module) | `modules/work-mount.nix` | pc, notebook |

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
| Swap: zram hot tier, NVMe overflow tier, `vm` sysctls | `modules/swap.nix` | The 32 GiB box ran with no swap at all and took 70 kernel OOM kills in 9 days of uptime (steamwebhelper, chrome, electron): `pgsteal_anon` was 0 while 72M file pages refaulted, so every byte of reclaim pressure landed on the page cache. `zram0` is `zstd` sized at 50% of RAM, `swap-priority` 100; `/var/lib/swapfile`, 32 GiB on the root NVMe, is the overflow tier at priority 10 and is created once by `mkswap-var-lib-swapfile.service` (`dd`, not `fallocate`). `zswap.enabled=0` because the CachyOS kernel ships `CONFIG_ZSWAP_DEFAULT_ON` and zswap in front of a zram device compresses every page twice. `vm.swappiness` needs `lib.mkForce`: musnix (`audio.lowLatency`) defines it as 10 without `mkDefault`, and 10 keeps the kernel from using zram at all. `vm.watermark_scale_factor` 125 widens kswapd's headroom from ~31 MB to ~390 MB, the burst that OOM-killed renderers while gigabytes were still free |
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
| Monitor values (pc) | `hosts/configuration.nix` (monitors attrset) |
| Hardware (pc) | `hosts/hardware-pc.nix` |
| GPU profile (LACT: undervolt, fan curve, power profile) | `hosts/lact-pc.yaml` | Deployed to `/etc/lact/config.yaml` via `environment.etc`; GUI cannot save while it is a store symlink |
|RGB lighting (OpenRGB): device profiles + blanking|`pkgs/openrgb-profile.nix`|`openrgb-profile [--wait] default\|off`; `default` = GPU and DRAM dark, mouse on Spectrum Cycle, `off` = everything dark. Wired from `home-manager/modules/sway.nix` (sway `startup`, plus the shared `sway-power` script used by both the swayidle `timeout`/`resume` hooks and the DPMS toggle hotkey); the OpenRGB server itself is `services.hardware.openrgb` in `hosts/configuration.nix`, whose `preStart` strips the Keychron Q6 Max detector so the keyboard keeps its firmware lighting|
|Keyboard backlight (Keychron Q6 Max)|`pkgs/keychron-backlight.nix`|`keychron-backlight on\|off` over VIA raw HID (usage page 0xFF60, `id_custom_set_value` channel 3, value id 2 = RGB matrix effect; effect 0 = dark, stash restores the previous effect; `off` re-stashes nothing when already dark, so repeated blanking is safe). Separate from OpenRGB on purpose: the board's detector is stripped in `systemd.services.openrgb.preStart` so it keeps its QMK firmware effects. Chained into the same `sway-power` script in `home-manager/modules/sway.nix`, so idle blanking and the DPMS toggle hotkey dim it alike; `id_custom_save` is never sent, so nothing is written to the keyboard's EEPROM|
| Hardware watchdog (sp5100_tco) | `hosts/configuration.nix` | armed by `systemd.settings.Manager.RuntimeWatchdogSec`; self-reboot 60s after a hang |
| belphegor, gnupg, dconf | `hosts/configuration.nix` |

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
| Binary cache (harmonia) | `modules/harmonia.nix` |
| ZeroSSL ACME for nginx | `modules/zerossl.nix` |
| LiteLLM | `modules/litellm.nix` |
| Drive mounts | `modules/drive.nix` |
| Kernel (CachyOS) | `modules/kernel-cachyos.nix` |
| Grafana | `modules/grafana.nix` |
| Prometheus, Loki, Alloy (ships nginx/angie + docker container + fail2ban logs to Loki) | `modules/grafana.nix` |
| Grafana monitoring aggregator (imports shared contact points + per-service alert files) | `modules/monitoring/default.nix` |
| Grafana shared notification channels (Telegram contact point + agenix secret, reused by all alerts) | `modules/monitoring/contact-points.nix` |
| Grafana alert: tidal-syncer TIDAL re-login required (Prometheus metric alert) | `modules/monitoring/tidal-syncer.nix` |
| tidal-syncer daemon (native service: config, agenix secret, Prometheus scrape + Grafana dashboard) | `modules/tidal-syncer.nix` |
| FRP (Fast Reverse Proxy) | `modules/frp.nix` |
| Grafana alert: frp tunnel connection lost (Loki log alert on frp-server journal) | `modules/monitoring/frp.nix` |
| Syncthing (server) | `modules/syncthing/server.nix` |
| Syncthing common module | `modules/syncthing/default.nix` |
| Syncthing device IDs | `modules/syncthing/devices.nix` |
| NVIDIA GT 210 | `modules/nvidia/gt210.nix` |
| Vaultwarden | `modules/vaultwarden.nix` |
| qBittorrent | `modules/qbittorrent.nix` |
| AmneziaWG | `modules/awg/default.nix` |
| AmneziaWG compose stack | `modules/awg/compose.nix` |
| Network (server) | `modules/network/default.nix` |
| Recursive validating DNS resolver (unbound, RFC 8806 local root zone) | `modules/unbound.nix` | Listens `127.0.0.1@5335` (dnsmasq keeps `127.0.0.1:53`), `192.168.1.2:53` (LAN), `10.8.0.1:53` (AWG clients); `access-control` allows only loopback/LAN/VPN and `deny`s the rest, so it is never an open reflector. Root zone comes by AXFR addressed by IP, never by name — a name would be circular for the zone that provides names. Primaries are ICANN's two transfer hosts first, then the five root servers measured to still serve AXFR (`b`, `c`, `d`, `f`, `k`); `a` refuses and `g` has stopped despite being listed in RFC 8806. `for-downstream = false` per the RFC, `for-upstream = true` so TLD delegations are answered from the local copy, `fallback-enabled = true` so a failed transfer degrades to ordinary recursion. Depends on a router-side exemption: the OpenWrt box runs `adblock-fast` with `force_dns`, whose `dstnat_lan` redirect hijacked every outbound port-53 packet and made recursion and DNSSEC impossible — see `docs/dns-resolver.md`. The server's own `/etc/resolv.conf` path (dnsmasq → router) is deliberately left untouched so `.lan`, the `labile.cc` split-horizon and the router's VPN domain policy keep working
| Encrypted DNS: DoT listeners, DoH terminator, shared TLS cert | `modules/unbound.nix` | DoT is unbound's own (`tls-port` 853 on `192.168.1.2` and `10.8.0.1` only, never public — DoT carries no token, so a public listener would be an open resolver). DoH cannot be unbound's: this nixpkgs builds it without `libnghttp2`, and even `withDoH = true` would not sit behind nginx because the DoH listener demands ALPN `h2` while `proxy_pass` speaks HTTP/1.1. So `services.doh-server` terminates DoH on `127.0.0.1:8053` and forwards plain DNS to `127.0.0.1@5335`. Beware: `unbound-checkconf` accepts `https-port`/`http-endpoint` on a build that lacks DoH, so that mistake fails silently. One ZeroSSL cert for `dns.labile.cc` serves both, shared through group `dns-tls` because `nginx.service` runs as `User=nginx` and nixpkgs asserts every consumer can read it. Client setup: `docs/dns-clients.md`; rationale: `docs/dns-resolver.md` |
| DoH public endpoint: vhost, rate limit, secret path | `modules/nginx.nix` + `hosts/configuration-server.nix` | Vhost `dns.labile.cc` on Angie 443 with `enableACME`, a `location /` that returns 404, and `limit_req_zone ... zone=doh` in `commonHttpConfig`. The secret URL path lives in the agenix secret `doh-location` because this repository is public; `hosts/configuration-server.nix` places it at `/run/doh-location.conf` with group `nginx`. It is included with a glob (`include /run/doh-location.conf*;`) so a missing secret cannot stop Angie serving the other vhosts — verified: the literal form aborts startup with `[emerg] open() ... failed`. Do not read it from `/run/agenix` directly: that directory is `drwxr-x--x root:keys`, and expanding a wildcard needs read on the directory, which the `nginx` user does not have |
| ifconfig.io container behind `ip.labile.cc` | `modules/ifconfig.nix` | `virtualisation.oci-containers` container `ifconfig` (image `georgyo/ifconfig.io`, tag `latest` as before), bound to `127.0.0.1:7006` only because Angie is its sole client, with `Restart = "always"` on `docker-ifconfig.service` the way `modules/awg/compose.nix` does it. Supersedes the hand-run compose file in `~/projects/ifconfig` on the server, which had no restart policy at all and left `ip.labile.cc` answering 502 once the container was gone |
| ChromaDB vector database service | `modules/chromadb.nix` |
| Hardware (server) | `hosts/hardware-server.nix` |

## Home Manager Modules (desktop only, `home-manager/modules/default.nix`)

| Task / Concern | File |
|---|---|
| HM entry point | `home-manager/modules/default.nix` |
| Sway window manager | `home-manager/modules/sway.nix` | Display power and peripheral lighting are one state, owned by one script: `sway-power on\|off\|toggle` (dpms + `openrgb-profile` + `keychron-backlight`), called by the swayidle launcher `sway-idle-power` (`timeout 1200` / `resume`) and by the `$mod+Shift+i` hotkey. sway leaves blanked outputs off until something powers them back on (swaywm/sway#2910), so after a manual blank the same hotkey is the only way back |
| Waybar status bar | `home-manager/modules/waybar.nix` |
| Wofi launcher | `home-manager/modules/wofi.nix` |
| Mako notifications | `home-manager/modules/mako.nix` |
| Git user config | `home-manager/modules/git.nix` |
| Alacritty terminal (disabled — import commented in `default.nix`, package kept as fallback) | `home-manager/modules/alacritty.nix` |
| Foot terminal — **default** (Wayland/C, minimalist, no tabs — panes via multiplexer; sixel images for omp) | `home-manager/modules/foot.nix` |
| Zellij multiplexer (parallel to tmux; direct Ctrl+a/d/x chords) | `home-manager/modules/zellij.nix` |
| btop resource monitor (user config; rocm-enabled package) | `home-manager/modules/btop.nix` |
| SSH user config | `home-manager/modules/ssh.nix` |
| MIME type associations | `home-manager/modules/mimeapps.nix` |
| mpv media player | `home-manager/modules/mpv.nix` |
| EasyEffects audio | `home-manager/modules/easyeffects.nix` |
| Yazi file manager | `home-manager/modules/yazi.nix` |
| Thunar (user config) | `home-manager/modules/thunar.nix` |
| yt-dlp | `home-manager/modules/yt-dlp.nix` |
| XDG user dirs | `home-manager/modules/xdg.nix` |
| Oh My Pi (omp) coding agent + undo-redo extension + MCP servers (`chroma`, `context7`, `sway`) in `~/.omp/agent/mcp.json` + user-level agent context: `RULES.md` (always-apply), `rules/commit-style.md` (TTSR, fires on `git commit`), `rules/code-comments.md` (TTSR, fires on comment blocks in edits), `rules/project-naming.md` (rulebook, read via `rule://`), `AGENTS.md` (session background) + mnemopi memory scoping | `home-manager/modules/omp.nix` | upstream oh-my-pi (`github:can1357/oh-my-pi`) `programs.omp` HM module loaded in `flake.nix` sharedModules; provider defs are emitted as `~/.omp/agent/models.yml`, config keys as `programs.omp.settings`; the five markdown documents are files under `home-manager/modules/omp/`, wired with `source =`, so editing a rule needs no Nix string escaping; a rule's bucket follows its frontmatter — `condition`/`astCondition` wins over `alwaysApply`, and a `description` with neither lands in the rulebook; project-scoped servers stay in that project's `.omp/mcp.json` — see "Other Files" for this repo's own `nix-control` server; memory is `mnemopi.scoping = "per-project"` — one isolated bank per project, no shared bank |
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
| Push store paths to the binary cache | `modules/cache-push.nix` (post-build hook) + `settings.nix` (trusted-users, substituters); `cache-push` helper in `modules/packages.nix` for backfill | automatic after every local build; `cache-push <path>` from any host | |
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
| Oh-my-pi register hook | `home-manager/modules/omp.nix` | sets `services.index-repo.omp.registerHook.enable`; extension source + deployment live in the index-repo flake (`hooks/omp/repo-register.js`) |

Connection options (ChromaDB host/port/ssl, debounce) are `services.index-repo.{host,port,ssl,debounce}` on the NixOS module. The systemd user unit (`index-repo serve`) is defined by the module — do NOT hand-write it. The opencode chroma-gate plugin + `chroma` MCP server come from the same index-repo HM module (`services.index-repo.opencode.{chromaGate,chromaMcp}`, enabled in `integrations.nix`); `chromaMcp.{host,port,ssl}` default to the NixOS `services.index-repo.{host,port,ssl}` via `osConfig`.

## Optional / Currently Unimported Modules

| Task / Concern | File | Notes |
|---|---|---|
| Virtual machines / libvirt | `modules/vm.nix` | Commented in `hosts/configuration.nix` |

## Other Files

| File | Purpose |
|---|---|
| `flake.nix` | Flake inputs, outputs, host wiring |
| `modules/shell/devshells.nix` | Per-language dev shells (`nix develop dev#<lang>`); imported by `flake.nix` outputs |
| `overlays.nix` | Custom package overlays |
| `settings.nix` | Common settings (nix settings, allowed packages) |
| `Makefile` | Convenience targets: `switch`, `boot`, `upgrade`, `fmt`, `cleanup`, `optimise` |
| `.omp/mcp.json` | Project-scoped MCP servers for this repo; edited here directly, not emitted by Home Manager |
| `.omp/nix-control-mcp/*.py` | The `nix-control` MCP server, split by concern: `config` constants, `protocol` JSON-RPC, `text` formatting, `shell` subprocess, `jobs` detached runs, `pane` sudo tmux pane, `system`/`flake`/`routes`/`rules`/`agenix` tools, `registry` schemas, `server` dispatch, `__main__` entry |
| `.omp/skills/nix-routing/SKILL.md` | Project skills live under `.omp/skills/`, loaded by omp's native skill provider |
