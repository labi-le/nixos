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
| LLM gateway API key for omp hosts (agenix `opencode-litellm-master-key`, consumed by `modules/omp/default.nix`) | `modules/opencode-secrets.nix` | Enabled for pc, server, notebook (hosts listed in the module) |
| Environment variables | `modules/env.nix` | |
| Network entry point | `modules/network/default.nix` | Imports DNS, firewall, hosts, proxy sub-modules |
| Network DNS | `modules/network/dns.nix` | Imported by `modules/network/default.nix` |
| Network firewall | `modules/network/firewall.nix` | Imported by `modules/network/default.nix` |
| Network hosts injection | `modules/network/hosts.nix` | Imported by `modules/network/default.nix` |
| Network proxy | `modules/network/proxy.nix` | Imported by `modules/network/default.nix` |
| System packages (all hosts) | `modules/packages.nix` | |
| btop user config (full default + show swap, all hosts) | `modules/btop.nix` | Deploys `~/.config/btop/btop.conf` via `systemd.tmpfiles` store symlink; imported + enabled per-host |
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
| Oh My Pi (omp) coding agent — the single omp implementation for every host (`modules/base.nix` imports it; the Home Manager module is gone and the old `mySystem.omp.enable` gate no longer exists); MCP servers (`chroma`, `context7`) in `~/.omp/agent/mcp.json`; user-level agent context (`RULES.md`, `rules/`, `AGENTS.md`); mnemopi memory scoping | `modules/omp/default.nix` | MCP servers are exactly `chroma` (stdio `uvx chroma-mcp` against the ChromaDB at `192.168.1.2:8000`, `modules/chromadb.nix`) and `context7` (http); payload files (`models.yml`, `mcp.json`, `lsp.json`, `keybindings.yml`, `AGENTS.md`, `RULES.md`, `rules/`, `extensions/`, vendored skills) live in `modules/omp/` beside `default.nix` and deploy as individual store paths via `systemd.tmpfiles.rules` `L+` symlinks into `~/.omp/agent/` (`~/.omp/agent` and its `skills/`, `rules/`, `extensions/` dirs are tmpfiles `d` entries, mode 0700, owner from the `user` module arg); `config.yml` is the exception — a writable regular file (mode 600) written by `system.activationScripts.ompConfig`, because omp rewrites it at runtime under a lock and a store symlink fails with EACCES; agent context: `RULES.md` (always-apply), `rules/commit-style.md` (TTSR, fires on `git commit`), `rules/code-comments.md` (TTSR, fires on comment blocks in edits), `rules/project-naming.md` (rulebook, read via `rule://`), `AGENTS.md` (session background); `extensions/` holds the gate extensions `comment-gate.ts` / `commit-gate.ts` plus the indexer's `repo-register.js` (see Code indexer wiring); a rule's bucket follows its frontmatter — `condition`/`astCondition` wins over `alwaysApply`, a `description` with neither lands in the rulebook; rules are plain-markdown store paths, so editing a rule needs no Nix string escaping; memory scoping is `mnemopi.scoping = "per-project"` — one isolated bank per project, no shared bank; project-scoped MCP servers stay in that project's own `.omp/mcp.json` (this repo's `nix-control` server — see Other Files), not in the agent-level one |

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
| Work secrets (agent tokens): opencode jira/gitlab/grafana + `portainer-mcp` (Portainer URL + API key) + `google-docs-mcp` (Google OAuth desktop client JSON for the `workspace-mcp` Docs server, read through `GOOGLE_CLIENT_SECRET_PATH=/run/agenix/google-docs-mcp`); all consumed by a project-scoped `.omp/mcp.json`, not by the omp module (`modules/omp/default.nix`) | `modules/work-mount.nix` | pc, notebook |

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
| Nginx; aborted HTTP/2 downloads, KTLS | `modules/nginx.nix`, `docs/nginx.md` |
| Binary cache (harmonia) | `modules/harmonia.nix`; fetch aborts: `docs/nginx.md` |
| ZeroSSL ACME for nginx | `modules/zerossl.nix` |
| LiteLLM | `modules/litellm.nix` |
| Drive mounts | `modules/drive.nix` |
| Kernel (CachyOS) | `modules/kernel-cachyos.nix` |
| Grafana | `modules/grafana.nix` |
| Prometheus, Loki, Alloy (ships nginx/angie + docker container + fail2ban logs to Loki) | `modules/grafana.nix` | Loki deletes nothing unless the compactor is told to: `retention_enabled` plus `delete_request_store = "filesystem"` (Loki 3.x refuses to start with the former and not the latter) and `limits_config.retention_period = "2160h"`. Ninety days, not a size cap — Loki has no size-based retention at all; measured ingest is 4.16 MB/day compressed, so the window lands near 375 MB with room for the rate to triple before it reaches 1 GB. The size-capped layer is journald (`modules/journald.nix`, `SystemMaxUse=1G`). Alloy pipes both nginx files through `loki.process` with a `stage.replace` that rewrites `?…` to `?redacted`, so URL query strings — DoH qnames, tokens, anything else in a URL — never enter the permanent store; `error.log` needs this because nginx logs the full request line of every rate-limited request |
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
| Recursive validating DNS resolver (unbound, RFC 8806 local root zone) | `modules/unbound.nix` | Listens `127.0.0.1@5335` (dnsmasq keeps `127.0.0.1:53`), `192.168.1.2:53` (LAN), `10.8.0.1:53` (AWG clients); `access-control` allows only loopback/LAN/VPN and `deny`s the rest, so it is never an open reflector. Root zone comes by AXFR addressed by IP, never by name — a name would be circular for the zone that provides names. Primaries are ICANN's two transfer hosts first, then the five root servers measured to still serve AXFR (`b`, `c`, `d`, `f`, `k`); `a` refuses and `g` has stopped despite being listed in RFC 8806. `for-downstream = false` per the RFC, `for-upstream = true` so TLD delegations are answered from the local copy, `fallback-enabled = true` so a failed transfer degrades to ordinary recursion. Depends on a router-side exemption: a `dstnat_lan` redirect hijacks every outbound port-53 packet, which makes recursion and DNSSEC impossible until this host's source address is returned first — see `docs/dns-resolver.md`. The server's own `/etc/resolv.conf` path (dnsmasq → router) is deliberately left untouched so `.lan`, the `labile.cc` split-horizon and the router's VPN domain policy keep working
| Encrypted DNS: DoT listener, shared apex TLS cert | `modules/unbound.nix` | DoT is unbound's own (`tls-port` 853 on `192.168.1.2` and `10.8.0.1` only, never public — DoT carries no path and no token, so a public listener would be an unlimited open resolver). The certificate is the apex `labile.cc` one, borrowed from the web vhost of that name and shared through group `dns-tls` (members: nginx, unbound users) plus `SupplementaryGroups` on the unbound unit and `reloadServices = [ "unbound" ]`, which HUPs it after renewal. Borrowing the apex cert is what let `dns.labile.cc` be deleted outright on 2026-08-26: a dedicated name needs its own HTTP-01 challenge, which needs an nginx vhost for exactly that name. The cost is coupling — if the apex vhost leaves this host, DoT must be repointed and every client's SNI changes. SAN holds one name, no wildcard: `openssl s_client -verify_hostname dns.labile.cc` now returns 62, `labile.cc` returns 0. DoH is gone with it; `services.doh-server` behind Angie was the only shape that could work, because this nixpkgs builds unbound without `libnghttp2` and even `withDoH = true` demands ALPN `h2` while `proxy_pass` speaks HTTP/1.1. Beware: `unbound-checkconf` accepts `https-port`/`http-endpoint` on a build that lacks DoH, so that mistake fails silently |
| DNS query logging and outbound rate limit | `modules/unbound.nix` | `log-replies = true` without `log-queries`: the reply line already carries client, qname, type, class, rcode, timing and size, so the query line is the same data at twice the journal volume. Attribution is no longer split across two logs — with DoH removed unbound sees each client's real address directly, so one journal line answers who asked what. `LogRateLimitBurst = 3000` per 30 s stays on the unit so per-query logging cannot evict sshd, sudo or fail2ban history from the 1 GB journal. `ratelimit = 1000` caps outbound queries per target zone so a random-subdomain flood cannot leave this host as the address a victim's authoritative servers blocklist; `ip-ratelimit` is now technically usable but deliberately unset, since the router's stubby multiplexes the whole LAN behind one address and an untuned per-IP cap would be a self-inflicted outage. The Alloy `stage.replace` that rewrites `?…` to `?redacted` stays in `modules/grafana.nix`, now protecting ordinary vhosts rather than DNS query strings |
| Ad and tracker filtering, blocklist refresh | `modules/unbound.nix` | Two `rpz:` zones scoped by `access-control-tag` to `192.168.1.0/24` and `10.8.0.0/24` only, so `127.0.0.1@5335` stays an unfiltered diagnostic path and comparing a filtered answer against an honest one is one `dig -p 5335`; every real client now sits inside those two netblocks. `respip` must lead `module-config` or the clauses are silently inert, and `interface-tag` cannot be used for the scoping: the manual's rule that any `access-control*:` overrides all `interface-*:` was confirmed by test. `rpz.local.` is listed first and generated into the store from Nix allow/block lists, because a `passthru` in the first zone beats a block in the second — that is both the false-positive exception mechanism and where `adfox.ru` and `vk-portal.net` are added, the Russian trackers no HaGeZi tier covers. `rpz.ads.` is HaGeZi Pro refreshed by `unbound-rpz-update.timer`, not by unbound's own `url:`, so a bad publish is rejected before activation: SOA in the header, at least 300 000 rules, and no canary blocked along its whole suffix chain. Canaries are public names only (`labile.cc`, `github.com`, top Russian services); work suffixes are deliberately excluded, since their owner is the router's imperative dnsmasq and a second copy here would drift silently in the dangerous direction, while reading them from a runtime file made the daily refresh fail closed on that file. Incident fix instead of a list: `rpz_disable`, or a `localAllow` passthru which beats any block in `rpz.ads.`. Failure keeps the old zone. Costs 285 MB resident against 33 MB before, and ~2 s of startup parsing; `unbound-control rpz_disable rpz.ads.` is the no-rebuild kill switch |
| Router-side DNS hijack, adblock-fast removal (not nix-managed) | `docs/dns-clients.md` | The OpenWrt box is imperative, so the recipe lives in the docs and the rationale in `docs/dns-resolver.md`. `adblock-fast` was removed on 2026-08-26 along with its luci app and `/etc/config/adblock-fast`: it filtered nothing at all — empty `status`, no blocklist artifact on disk, `/tmp/dnsmasq.d` and `/var/run/adblock-fast` both empty, ad domains resolving to real addresses — while its ubus rules were the only live effect. The half worth keeping is now four static rules in `/usr/share/nftables.d/chain-pre/dstnat_lan/10-dns-hijack.nft`, listed in `/etc/sysupgrade.conf`: two `return` rules for `ip saddr 192.168.1.2` that must stay above the two `redirect to :53`, or the server's own recursion is hijacked back into the router and DNSSEC dies silently. The hijack is what makes filtering unbypassable — `dig @8.8.8.8 an.yandex.ru` from a LAN host answers NXDOMAIN from our chain. The old `dport 853 jump handle_reject` was deliberately not reproduced: it made every third-party DoT resolver unreachable from the LAN and protected nothing, since an external encrypted resolver bypasses filtering anyway. mihomo stays between dnsmasq and stubby because `enhanced-mode: fake-ip` with `MATCH,real-ip` is what routes the `vpn`, `telegram` and `warp` rule-sets through the proxy; it caches positive answers, so a newly blocked name can outlive the RPZ by a TTL |
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
| SSH user config | `home-manager/modules/ssh.nix` |
| MIME type associations | `home-manager/modules/mimeapps.nix` |
| mpv media player | `home-manager/modules/mpv.nix` |
| EasyEffects audio | `home-manager/modules/easyeffects.nix` |
| Yazi file manager | `home-manager/modules/yazi.nix` |
| Thunar (user config) | `home-manager/modules/thunar.nix` |
| yt-dlp | `home-manager/modules/yt-dlp.nix` |
| XDG user dirs | `home-manager/modules/xdg.nix` |

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
| System service | `inputs.index-repo.nixosModules.default` | `modules/omp/default.nix` imports the module itself and sets `services.index-repo.{enable,host,package}` (`host` = `192.168.1.2`, the ChromaDB target — see below); the omp module is imported for every host via `modules/base.nix` |
| Oh-my-pi register hook | `~/.omp/agent/extensions/repo-register.js` | Deployed by `modules/omp/default.nix` as an `L+` symlink (via `systemd.tmpfiles.rules`) to a store copy of upstream `hooks/omp/repo-register.js` with `@index_repo_bin@` replaced by `${pkgs.index-repo}/bin/index-repo` |

Connection options (ChromaDB host/port/ssl, debounce) are `services.index-repo.{host,port,ssl,debounce}` on the NixOS module — `host` is the ChromaDB target the indexer writes to (`192.168.1.2`, `modules/chromadb.nix`), not a listen address. The systemd user unit (`index-repo serve`) is defined by the module — do NOT hand-write it. `users.users.<user>.linger = true` is set by `modules/omp/default.nix` — required because the server has no interactive login, hence no user manager, so the user unit never starts without it.

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
| `.omp/mcp.json` | Project-scoped MCP servers for this repo; edited here directly, not generated by the omp module (`modules/omp/default.nix`) |
| `.omp/nix-control-mcp/*.py` | The `nix-control` MCP server, split by concern: `config` constants, `protocol` JSON-RPC, `text` formatting, `shell` subprocess, `jobs` detached runs, `pane` sudo tmux pane, `system`/`flake`/`routes`/`rules`/`agenix` tools, `registry` schemas, `server` dispatch, `__main__` entry |
| `.omp/skills/nix-routing/SKILL.md` | Project skills live under `.omp/skills/`, loaded by omp's native skill provider |
