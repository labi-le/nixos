# fail2ban on `server`

Jails live in `modules/network/firewall.nix` (globals, `sshd`),
`modules/nginx.nix` (nginx jails) and `modules/frp.nix` (`frp-auth`);
this carries only what those modules cannot say.

## The sshd jail was blind for its whole life

The stock filter's `journalmatch` is `_SYSTEMD_UNIT=sshd.service +
_COMM=sshd`. OpenSSH 9.8 split session handling into a separate
`sshd-session` binary — [release note](https://www.openssh.org/txt/release-9.8),
"Potentially-incompatible changes" — so `_COMM=sshd` no longer matches
a login attempt. Measured over seven days: 5538 journal entries with
`_COMM=sshd-session` against 20 with `_COMM=sshd`, ban counter zero
for the jail's entire existence. Fixed by dropping `_COMM` from
`journalmatch` in `modules/network/firewall.nix`.

## Rejected: restoring the client address behind Cloudflare

`set_real_ip_from` plus `real_ip_header CF-Connecting-IP` was
rejected. In the 2026-09-20–22 sample (16557 lines of
`/var/log/nginx/access.log`), only 49 requests arrived from
Cloudflare's published proxy ranges, 47 of them
`GET /wp-admin/install.php` probes — no legitimate traffic would
benefit. Worse, it would move `ip_whitelist.conf`'s allow/deny, the
`/nginx_status` allow rule and fail2ban's `ignoreip` matching from
the verified TCP source onto a forgeable header, and a ban keyed on
the rewritten address installs a rule the packets never match —
the packet source stays the edge, so the ban is decorative.

## The exemption list is per jail, not `[DEFAULT]`

`nginxJailIgnoreIp` in `modules/nginx.nix` is attached to each of the
four nginx jails individually, not `[DEFAULT]`: a `[DEFAULT]` entry
would also disarm `sshd`, and
`services.openssh.settings.PasswordAuthentication` is `true`.

`104.28.0.0/16` is Cloudflare WARP egress, deliberately absent from
Cloudflare's published proxy-IP list, so that list alone would not
cover the addresses `nginx-scan-404` actually banned:
`104.28.222.47` and `104.28.160.163`, both banned for five hours on
2026-09-21. `104.16.0.0/12`, Cloudflare's ARIN allocation, covers
both and is used instead.
`93.100.194.40`, this host's own public address, is in the list
because mailcow's hourly ACME pre-flight reaches nginx through NAT
reflection: 126 `/.well-known/acme-challenge/` 404s in the sample,
clustering three inside 60s against `nginx-scan-404`'s `maxretry =
5` — without the exemption the host can ban its own address.

## Two filter traps

`nginx-404.conf`'s `ignoreregex` used to be `\.(css|js|...)$`. It
never matched a single line: nginx's `combined` format ends with the
quoted User-Agent, not the request path, so the `$` anchor was
unreachable — measured, `Ignoreregex: 0 total` across all 16557
sample lines with `fail2ban-regex`. Once anchored to the request
field it matched, a second trap appeared: naive anchoring on `"..."`
still lets an attacker's own Referer or User-Agent supply the opening
quote, so a client sending `GET /x.css HTTP` as either header value
got every request ignored. The fix runs the anchor through
quote-free spans (`[^"]*`, never `.*`) so it cannot cross the request
field's closing quote.

`js` in the same list exempted 49 of 90 ignored lines in the sample —
`/config.js`, `/env.js`, `/credentials.js` and similar probes, not
static assets — so it was dropped.

## Bans are scoped to the ports nginx actually serves

A jail name outside fail2ban's stock set inherits `port = 0:65535`
from `[DEFAULT]`, per
[jail.conf(5)](https://manpages.debian.org/testing/fail2ban/jail.conf.5.en.html)
— an HTTP 404 ban used to remove ssh (22), DoT (853) and NFS (2049)
too. nginx serves three ports, not two — 80, 443 and
`93.100.194.40`'s `38264` vhost — so all four jails carry
`port = "http,https,38264"`.

## The frp control-port jail

A failed token login splits across two adjacent `frp-server` journal
lines — address on `client login info`, verdict on the following
`register control error` — so `frp-auth.conf` needs `maxlines = 2`
in `[Init]` to join them before `failregex` runs.
The control port (38392) is reachable only as QUIC, so the ban
action is `protocol = "udp"` — a default TCP ban installs a rule no
packet ever matches. The proxied ports 16666-16670 carry a remote
machine's own RDP/SSH whose auth this host never observes; firewall
counters showed zero packets on them, so rate-limiting them was
rejected — nothing here to rate-limit against.

## What fail2ban buys, and mailcow's chain fight (2026-09-22)

A scanner emits 200-280 requests in one minute; the ban lands 0-60s
later. Over three days to 2026-09-22, 2540 requests arrived before a
ban landed and 240 after — about 9%. No probe has ever received a
2xx; the value is repeat-visit suppression and log volume, not
prevention.

Mailcow's `netfilter` container insists on holding the first jump in
`ip filter INPUT`, and restarts itself whenever fail2ban's chain
insertion knocks it out of that spot — clearing every mail ban it
held. Three such restarts and 14 `Clearing all bans` lines in the
seven days to 2026-09-22. Nothing here fixes it; the container
self-heals and mail bans start over.

## Verify

```sh
sudo fail2ban-client status sshd
sudo fail2ban-client status nginx-secret-probe
sudo fail2ban-client status frp-auth
```
Expected: `Currently failed`/`Total failed` climbing; `sshd` stuck
at zero is the original bug — cross-check with the probe below.

```sh
ssh invaliduser@<server-address>   # from another host, once
sudo journalctl -u fail2ban -n 50 | grep sshd
```
Expected: `[sshd] Found <your-address>` within a few seconds. No
`Found` line means journalmatch or the filter regressed again, not
that fail2ban is "not done yet".

```sh
sudo iptables -S
```
Fails here with `Failed to initialize nft: table 'filter' is
incompatible, use 'nft' tool.` — mailcow's `netfilter` container
writes nftables-native rules into the same table and `iptables-nft`
refuses to read past them. `nft` is in the nix store but not on the
system `PATH` (only `modules/awg/default.nix` gives it to one
service's `path`); read the chain instead with:
```sh
sudo nix run nixpkgs#nftables -- list table ip filter
```
Expected: `chain f2b-sshd`, `f2b-nginx-secret-probe` etc., `jump`
rules ahead of mailcow's own chain. An empty or missing `f2b-*`
chain after a `switch` means the actions never ran, not that
nothing is currently banned.

```sh
sudo fail2ban-regex /var/log/nginx/access.log \
  /etc/fail2ban/filter.d/nginx-secret-probe.conf
```
Expected: nonzero `Failregex`, `Ignoreregex: 0 total` (this filter
carries none). A large `Ignored` count here, or any hit on
`nginx-404.conf`'s ignoreregex without checking which paths were
ignored, means the anchor regressed into matching the User-Agent or
Referer — rerun with `User-Agent: GET /x.css HTTP` and confirm it
lands in `Missed`, not `Ignored`.
