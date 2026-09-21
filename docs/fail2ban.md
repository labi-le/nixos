# fail2ban on `server`

Jails live in `modules/network/firewall.nix` (globals, `sshd`),
`modules/nginx.nix` (nginx jails) and `modules/frp.nix` (`frp-auth`); this
carries only what those modules cannot say.

## The sshd jail was blind for its whole life

The stock filter's `journalmatch` is `_SYSTEMD_UNIT=sshd.service + _COMM=sshd`.
OpenSSH 9.8 split session handling into a separate `sshd-session` binary —
[release note](https://www.openssh.org/txt/release-9.8),
"Potentially-incompatible changes" — so `_COMM=sshd` no longer matches a login
attempt. Measured over seven days: 5538 journal entries with
`_COMM=sshd-session` against 20 with `_COMM=sshd`, ban counter zero for the
jail's entire existence. Fixed by dropping `_COMM` from `journalmatch` in
`modules/network/firewall.nix`.

## Rejected: restoring the client address behind Cloudflare

`set_real_ip_from` plus `real_ip_header CF-Connecting-IP` was rejected: in the
2026-09-20–22 sample (16557 lines of `/var/log/nginx/access.log`) only 49
requests came from Cloudflare's published proxy ranges, 47 of them `GET
/wp-admin/install.php` probes, so no legitimate traffic benefits. It would also
move `ip_whitelist.conf`, `/nginx_status` and `ignoreip` matching onto a
forgeable header, and a ban keyed on the rewritten address never matches the
real packets — decorative, since the source stays the edge.

## The exemption list is per jail, not `[DEFAULT]`

`nginxJailIgnoreIp` in `modules/nginx.nix` is attached to each of the four
nginx jails individually, not `[DEFAULT]`: a `[DEFAULT]` entry would also
disarm `sshd`, and `services.openssh.settings.PasswordAuthentication` is
`true`. `104.28.0.0/16` is Cloudflare WARP egress, missing from Cloudflare's
published proxy-IP list — `104.16.0.0/12`, the ARIN block, covers it and both
`nginx-scan-404` bans it missed (`104.28.222.47`, `104.28.160.163`).
`93.100.194.40`, this host's own address, is listed because mailcow's hourly
ACME pre-flight reaches nginx through NAT reflection (126
`/.well-known/acme-challenge/` 404s in the sample) — without it the host can
ban itself.

## Two filter traps

`nginx-404.conf`'s `ignoreregex` used to be `\.(css|js|...)$` and never
matched: nginx's `combined` format ends with the quoted User-Agent, not the
request path, so `$` was unreachable — `Ignoreregex: 0 total` across all 16557
sample lines. Anchored to the request field instead, but a naive `"..."` anchor
lets an attacker's Referer or User-Agent supply the opening quote, so `GET
/x.css HTTP` in either header ignored every request; fixed with quote-free
spans (`[^"]*`, never `.*`). `js` in the same list exempted 49 of 90 ignored
lines in the sample — `/config.js`, `/env.js`, `/credentials.js` probes, not
static assets — so it was dropped.

## Bans are scoped to the ports nginx actually serves

A jail name outside fail2ban's stock set inherits `port = 0:65535` from
`[DEFAULT]`, per
[jail.conf(5)](https://manpages.debian.org/testing/fail2ban/jail.conf.5.en.html)
— an HTTP 404 ban used to remove ssh (22), DoT (853) and NFS (2049) too. nginx
serves 80, 443 and `93.100.194.40`'s `38264` vhost, so all four jails carry
`port = "http,https,38264"`.

## The frp control-port jail

A failed token login splits across two adjacent `frp-server` journal lines —
address on `client login info`, verdict on `register control error` — so
`frp-auth.conf` needs `maxlines = 2` in `[Init]` to join them before
`failregex` runs. The control port (38392) is reachable only as QUIC, so the
ban action is `protocol = "udp"` — a default TCP ban installs a rule no packet
matches. The proxied ports 16666-16670 carry a remote machine's own RDP/SSH;
firewall counters showed zero packets there, so rate-limiting them was
rejected.

## Mailcow's chain fight, and moving fail2ban to nftables (2026-09-22)

A scanner emits 200-280 requests/minute; the ban lands 0-60s later, letting
2540 of 2780 requests (91%, 3-day sample) through first — no probe has ever
gotten a 2xx, so the value is repeat-visit suppression, not prevention.
Mailcow's `netfilter` container demands the first jump in `ip filter INPUT` and
restarted itself, clearing every mail ban, whenever fail2ban's
`iptables-multiport` action ran `-I INPUT 1` ahead of it. Measured 2026-09-21
(`journalctl --since 2026-09-08`; container journald retained only from
2026-09-19, ~2.3 days): 27 `CRIT:` lines — 8 chain-fight restarts, 19 unrelated
mail-ban `Clearing all bans`. Six restarts named `ip filter INPUT`, two named
`ip forward` (docker's `DOCKER-USER`/`DOCKER-FORWARD` reinsert there on every
dockerd restart; this change does not touch it, so a future forward-table CRIT
is docker, not a regression). Fixed by moving [`banaction`][banaction] /
`banaction-allports` to `nftables-multiport` / `nftables-allports` and
[`packageFirewall`][packageFirewall] to `pkgs.nftables`: fail2ban now owns
`table inet f2b-table` (`filter - 1`) instead of `ip filter INPUT`, so mailcow
keeps position 1 there for good. `packageFirewall` also drops iptables from the
unit `PATH` (`nftables-1.1.6/bin`, no `iptables`), so a future iptables action
fails `command not found`. `networking.nftables.enable` stays `false`: flipping
it breaks `modules/awg/default.nix`'s `extraCommands` (assertion in
`.../firewall-nftables.nix`) and drops `ip_tables` (`.../nftables.nix:277`)
docker/mailcow need (checked 2026-09-21).

## Rejected: fixing this on the mailcow side

Editing `/opt/mailcow-dockerized/docker-compose.override.yml`, or disabling
mailcow's `netfilter` container, was rejected: the conflict is built entirely
on the host side by fail2ban's `-I INPUT 1` insert, and that container's
Redis-driven ban UI stays needed.

## Verify

```sh
sudo fail2ban-client status sshd
sudo fail2ban-client status nginx-secret-probe
sudo fail2ban-client status frp-auth
ssh invaliduser@<server-address>   # from another host, once
sudo journalctl -u fail2ban -n 50 | grep sshd
```
Expected: `Currently failed`/`Total failed` climbing and `[sshd] Found
<your-address>` logged. Stuck at zero, or no `Found`, means journalmatch/filter
regressed.

```sh
sudo iptables -S
sudo nix run nixpkgs#nftables -- list chain ip filter INPUT
sudo docker inspect mailcowdockerized-netfilter-mailcow-1 \
  --format '{{.State.StartedAt}}'
```
Expected: `iptables -S` fails (`table 'filter' incompatible, use 'nft' tool` —
mailcow owns nftables-native rules, `nft` isn't on `PATH`); `list chain` shows
`jump MAILCOW` first, four `wg0` rules, `jump nixos-fw`; uptime steady at
`2026-09-21T22:40:59.281103201Z`. Displaced MAILCOW, an `f2b-*` jump, or a
later uptime means a restart (chain fight or docker's separate forward-chain
fight).

```sh
sudo fail2ban-client set frp-auth banip 198.51.100.9
sudo nix run nixpkgs#nftables -- list table inet f2b-table
sudo fail2ban-client set frp-auth unbanip 198.51.100.9
```
Expected: ban adds `udp dport 38392 ip saddr @addr-set-frp-auth` (never `tcp`,
QUIC) to `f2b-chain`; unban empties the set. Table appears on demand at the
first ban — absent with nothing banned is normal, not proof the action never
ran.

```sh
sudo fail2ban-regex /var/log/nginx/access.log \
  /etc/fail2ban/filter.d/nginx-secret-probe.conf
```
Expected: nonzero `Failregex`, `Ignoreregex: 0 total`. Large `Ignored` means
the anchor regressed into User-Agent/Referer — rerun with `User-Agent: GET
/x.css HTTP`, confirm `Missed` not `Ignored`.

[banaction]: https://search.nixos.org/options?query=banaction
[packageFirewall]: https://search.nixos.org/options?query=packageFirewall
