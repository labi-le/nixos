# DNS resolver on `server`

`modules/unbound.nix` runs unbound as a validating, recursive resolver with a
local copy of the root zone (RFC 8806, which obsoletes RFC 7706). It is a
second, independent resolver that sits *beside* the existing DNS path instead of
replacing it.

## Listeners

| Address | Purpose |
|---|---|
| `127.0.0.1@5335` | administration and verification from the host |
| `192.168.1.2:53` | LAN clients and the router, when pointed here explicitly |
| `10.8.0.1:53` | AmneziaWG clients; `modules/awg/default.nix` already accepts `udp/53` on `wg0` |
| `192.168.1.2@853` | DoT for LAN clients |
| `10.8.0.1@853` | DoT for VPN clients |

Port 53 on loopback stays with dnsmasq. `access-control` allows only
`127.0.0.0/8`, `192.168.1.0/24` and `10.8.0.0/24`; everything else is `deny`,
which drops silently and gives no amplification surface. That ACL, not the
firewall, is what keeps 53 and 853 off the internet: the rules are scoped to
`enp37s0` and `wg0` rather than globally, but public traffic arrives on
`enp37s0` too, DNAT'ed by the router to `192.168.1.2`, so a mistaken port
forward would pass the firewall and be refused by unbound instead. Client-facing
setup for DoT is in `docs/dns-clients.md`.

## Encrypted transports

DoT is unbound's own, because that needs nothing but `tls-port` and a
certificate. It listens on the LAN and VPN addresses only, never publicly: the
protocol carries no path and no token, so a public listener would be an
unlimited open resolver with no access control available at any layer.

The certificate is the one already issued for the apex name `labile.cc`, shared
with the web vhost of the same name through group `dns-tls`, whose members are
the nginx and unbound users; unbound gets it via `SupplementaryGroups` and
`reloadServices = [ "unbound" ]` on the ACME cert sends a HUP after each
renewal. There is deliberately no certificate of the resolver's own any more.
`dns.labile.cc` had one until 2026-08-26, together with an nginx vhost that
existed at the end only to answer the HTTP-01 challenge for it; both are gone.
Clients authenticate the transport as `labile.cc`, and the SAN list holds that
single name with no wildcard, so nothing else validates: measured,
`openssl s_client -verify_hostname dns.labile.cc` against `192.168.1.2:853`
returns code 62 while `labile.cc` returns 0.

DoH is not offered at all. It was served briefly by `services.doh-server`
behind Angie on 443, forwarding plain DNS to `127.0.0.1@5335`, and it was
removed on 2026-08-26 as unused: it was the only
publicly reachable part of the resolver, and keeping it honest cost a daemon, a
`limit_req` zone, a fail2ban jail, a dedicated log format and a permanent
cache-snooping oracle for strangers. Measured before removal, it was not even
faster to give up: on the LAN plain 53, DoT and DoH were indistinguishable at
`dig`'s 1 ms resolution on cache hits, and on a cold name DoT took 9 ms against
DoH's 10 ms.

Should anyone want it back, the trap that made the first attempt expensive is
still there. The unbound in this nixpkgs is built without `libnghttp2`
(`unbound -V` reports only libevent and OpenSSL), so its own DoH listener does
not exist, and `unbound-checkconf` accepts `https-port` and `http-endpoint`
regardless — a silent failure rather than a build error. Rebuilding with
`withDoH = true` would not help either: that listener requires ALPN `h2`
unconditionally (`util/netevent.c` sets `http_min_version = http_version_2` and
drops any connection that does not negotiate `h2`), while nginx speaks HTTP/1.1
to upstreams and can never sit in front of it. A separate daemon is the only
shape that works, which is what was removed.

`ratelimit: 1000` stays, capping unbound's outbound queries per target zone so a
random-subdomain flood cannot leave this host as the address a victim's
authoritative servers see and blocklist. Its old companion argument is obsolete:
`ip-ratelimit` was useless while every DoH query arrived as `127.0.0.1`, and now
that every client is a LAN, VPN or loopback address it would work — it is
deliberately not enabled, because the remaining clients are trusted and an
untuned per-IP cap on the router's stubby, which multiplexes the whole LAN
behind one address, would be a self-inflicted outage.

Query logging is `log-replies` in unbound and nothing else. Not `log-queries` —
the reply line carries the client, qname, type, class, rcode, timing and answer
size, so the query line duplicates it at twice the journal volume. Attribution
is no longer split between two logs: unbound now sees each client's real
address directly, so a single journal line answers who asked what. The Alloy
pipeline still rewrites every `?…` in an nginx line to `?redacted` before it
reaches Loki, but that now protects the ordinary vhosts rather than DNS query
strings, and it stays for that reason. `LogRateLimitBurst = 3000` per 30 s
remains on the unbound unit so per-query logging cannot evict sshd, sudo and
fail2ban history from the 1 GB journal.

One caution for whoever audits this next: `cert.pem` in every ACME directory
shows as `lrwxrwxrwx`, which looks like a world-writable key and is not one. It
is a symlink to `fullchain.pem`, and symlink modes are always 0777 on Linux;
`find -printf %m` reports the link, not the target. The real files are 0640,
owned `acme:dns-tls` for the apex certificate this resolver shares. Do not
"fix" it with a chmod, which would replace the link.

## Filtering

Ads and trackers are filtered through two RPZ zones, and the filtering applies
to *tagged clients only*: `access-control-tag` marks `192.168.1.0/24` and
`10.8.0.0/24` with the tag `ads`, and both `rpz:` clauses carry `tags: "ads"`.
Since the public DoH endpoint was removed every remaining client is inside one
of those two netblocks, so in practice everything that asks is filtered. The
tags are not vestigial for that reason: loopback stays untagged, which keeps
`127.0.0.1@5335` an honest diagnostic path, and comparing a filtered answer
against an unfiltered one is then a single `dig -p 5335` rather than a
`rpz_disable` on the live daemon. Measured, the same name is NXDOMAIN for a LAN
client on plain 53 and over DoT, and NOERROR on the admin port. Delete the tags
and that comparison is gone.

`respip` must lead `module-config` (`"respip validator iterator"`) or every
`rpz:` clause is silently inert — no error, no filtering. The obvious way to
scope filtering, `interface-tag` on the LAN and VPN listeners, does not work
here: the manual states that any `access-control*:` option overrides all
`interface-*:` options for targeted clients, and a test confirmed it — with
`tags:` set, a tagged listener filtered nothing, while removing `tags:`
filtered on every listener. Client-address tagging is the only mechanism that
survives an `access-control` block, and `define-tag` must be parsed before
anything that references a tag.

The zone order matters and is load-bearing. `rpz.local.` comes first: a
hand-maintained zone generated into the store from two Nix lists, an allow list
emitting `CNAME rpz-passthru.` and a block list emitting `CNAME .`, each for
both the name and its wildcard. A `passthru` in the first zone beats a block in
the second, verified, so that list is the exception mechanism for a false
positive as well as the place to add what upstream misses. It currently blocks
`adfox.ru` and `vk-portal.net`, the two Russian ad domains that no HaGeZi tier
covers. Unbound never rewrites a zonefile that has no primary or url, so the
store path is safe as a zonefile.

`rpz.ads.` is HaGeZi Pro, 452 190 rules, fetched by `unbound-rpz-update.timer`
rather than by unbound's own `url:` option. The daemon can download and refresh
a zone itself, and the list ships a usable SOA, but then a bad publish is
activated unvalidated and a stuck HTTP fetch lives inside the DNS daemon. The
unit downloads to a temporary file and refuses to activate it unless the header
carries an SOA, the rule count is at least 300 000, and no canary is blocked;
only then does it `mv` into place and call `unbound-control auth_zone_reload
rpz.ads.`, which reloads without a restart. Any failure leaves the previous
zone serving — observed for real when the first run rejected a good list
because `grep -q` exiting early under `pipefail` turned a broken pipe into a
failed SOA check.

The canaries are the eight `*.work-parent.example` work portals, `labile.cc`, and the
Russian services whose loss would be noticed first. Each is checked along its
whole suffix chain, so a `*.work-parent.example` entry upstream would be caught rather than
silently costing access to work. This is not hypothetical: the list already
blocks `work-analytics.example`, which is analytics on a government site and correct to
block, but it proves upstream does write `work-parent.example` rules.

The cost is 285 MB resident, up from 33 MB, and about two seconds added to
startup while 452 190 rules parse — during which the resolver answers nothing,
so a restart is now perceptible. The host has 31 GiB. `rpz-log` is on and each
block is journalled with the client address (`rpz: applied [ads] mc.yandex.ru.
rpz-nxdomain 192.168.1.3@54088`); those lines stay in journald, because Alloy
ships nginx, docker and two journal units to Loki but not unbound.

When something breaks, the escape hatch needs no rebuild and no restart:
`unbound-control rpz_disable rpz.ads.` turns the blocklist off, `rpz_enable`
turns it back on, both verified live.

Scope is wider than it first appears, and an earlier version of this document
got it wrong. The whole LAN is filtered, not merely the encrypted clients,
because the router's chain terminates here: a client asks dnsmasq on
`192.168.1.1:53`, dnsmasq forwards everything general to mihomo on
`127.0.0.1:12344`, and mihomo's only upstream is stubby on `127.0.0.1:5453`,
which speaks DoT to this resolver. mihomo runs `enhanced-mode: fake-ip` with
`fake-ip-filter-mode: rule`, and its filter list ends with `MATCH,real-ip`, so
only the `vpn`, `telegram` and `warp` rule-sets are answered with a
`198.18.1.0/24` placeholder; everything else is resolved for real by us. The
router queries as `192.168.1.1`, which is inside the tagged netblock, so LAN
clients receive the same NXDOMAIN a DoT client gets. Measured through all three
layers: `an.yandex.ru` is NXDOMAIN at stubby, at mihomo and at dnsmasq, while
`example.com` resolves.

mihomo must stay in that path. Its DNS answers are how proxy routing is decided
for the three rule-sets above, so pointing dnsmasq straight at this resolver
would resolve those domains honestly and route them direct instead of through
the proxy. It also caches positive answers, which is why a newly blocked name
can keep resolving for a while: `mc.yandex.ru` kept returning `77.88.21.119`
through the client path after the RPZ went live, and only a mihomo restart
cleared it, while the same name was already NXDOMAIN one layer deeper at stubby.

Coverage against Russian analytics, measured from a tagged client: HaGeZi Light
blocked 19 of 24 tested names, Pro blocked 22, and the two local additions make
it 24. Blocked by both tiers are `mc.yandex.ru`, `an.yandex.ru`,
`ads.adfox.ru`, `yandexadexchange.net`, `top-fwz1.mail.ru`, `rs.mail.ru`,
`ad.mail.ru`, `tns-counter.ru`, `counter.yadro.ru`, the Rambler counters,
`adriver.ru`, `dmg.digitaltarget.ru`, `openstat.net` and `spylog.com`; Pro adds
`appmetrica.yandex.ru`, `mc.admetrica.ru` and `ads.vk.com`. Nothing in
`yandex.ru`, `mail.ru`, `vk.com`, `gosuslugi.ru`, `sberbank.ru`, `ozon.ru`,
`wildberries.ru`, `avito.ru`, the work portals or `labile.cc` is affected.

DoT uses the ZeroSSL certificate of the apex name `labile.cc`, issued by the
existing HTTP-01 flow for the web vhost of that name. Two non-obvious
constraints govern how it is shared:

- `nginx.service` runs as `User=nginx`, not root, so nixpkgs asserts that every
  consumer can read the certificate. Group `unbound` fails that assertion.
  Hence group `dns-tls`, whose members are exactly the `nginx` and `unbound`
  users, plus `SupplementaryGroups` on the unbound unit and
  `reloadServices = [ "unbound" ]` so renewal reaches it through the existing
  `ExecReload=kill -HUP`.
- Borrowing the apex certificate is what allowed `dns.labile.cc` to disappear
  completely. A name of its own would need its own HTTP-01 challenge, and that
  needs an nginx vhost for exactly that name — the 404 stub that existed for one
  afternoon. The cost is that the transport authentication name is now tied to
  the main site's certificate: if that vhost ever moves off this host, DoT must
  be repointed at whatever certificate stays, and every client's SNI changes
  with it.

The root zone is transferred by AXFR, addressed by IP rather than by name,
because resolving a name would be circular for the zone that provides the
names. Only some sources serve those transfers: measured from this host,
`lax`/`iad.xfr.dns.icann.org` (`192.0.32.132`, `192.0.47.132`) and root servers
`b`, `c`, `d`, `f`, `k` each hand over all 24886 records, while `a` refuses and
`g` — listed in RFC 8806 — has since stopped, exactly as the RFC warns
operators eventually will. ICANN's two transfer hosts are tried first because
they are the designated distribution points; the five roots are fallbacks. Note
that RFC 8806's own example still names `b` as `199.9.14.201`, its pre-2023
address; `170.247.170.2` is the current one and both still answer.

`for-downstream = false` keeps unbound a resolver rather than a root server, as
the RFC requires, while `for-upstream = true` makes it answer TLD delegations
from the local copy and DNSSEC-validate that copy first. `fallback-enabled =
true` means a failed transfer degrades to ordinary recursion instead of an
outage.

## What is deliberately not touched

The host keeps resolving through `dnsmasq` on `127.0.0.1:53`, whose upstream is
the router at `192.168.1.1`. That path carries three things unbound cannot
answer:

- `.lan` names — `modules/nginx.nix` resolves `external.lan` for its whitelist
- the `labile.cc` split-horizon record, which maps to `192.168.1.2` on the LAN
  and to the public address from outside
- the router's per-domain VPN policy routing (`server=/domain/vpn-dns#5353`)

Repointing `/etc/resolv.conf` or the dnsmasq upstream at unbound would break all
three. Do not do it.

## Router-side prerequisite

Every port-53 packet leaving any LAN host is redirected into the router's own
dnsmasq, regardless of destination. A query sent to `192.0.2.1` (TEST-NET-1,
unroutable) answered in 0 ms with `aa` set, and asking that address for
`external.lan` returned `93.100.194.40`, a record that exists only on the
router. Behind that redirect a recursive resolver cannot work at all: root-zone
AXFR fails, iterative queries never reach the authoritative servers, and the
interceptor answers without an EDNS OPT record and strips RRSIG, so every signed
zone turns bogus and SERVFAILs. The server's own source address is therefore
returned before the redirect can match.

Until 2026-08-26 the redirect belonged to `adblock-fast`, which injected it
through ubus along with a reject rule for port 853. That package has been
removed: it filtered nothing whatsoever — empty `status` output, no blocklist
artifact anywhere on disk, `/tmp/dnsmasq.d` and `/var/run/adblock-fast` both
empty, and ad domains resolving to real addresses whenever the server's RPZ did
not block them — while costing a 90 KB init script and a luci app. Its one
worthwhile effect now lives in a static file,
`/usr/share/nftables.d/chain-pre/dstnat_lan/10-dns-hijack.nft`:

```
ip saddr 192.168.1.2 udp dport 53 counter return comment "server recursion egress"
ip saddr 192.168.1.2 tcp dport 53 counter return comment "server recursion egress"
udp dport 53 counter redirect to :53 comment "hijack lan plain dns"
tcp dport 53 counter redirect to :53 comment "hijack lan plain dns"
```

Order inside the file is load-bearing: the two `return` rules must precede the
redirects, or the server's recursion is hijacked back into the router and DNSSEC
dies silently. Four static rules cost nothing at runtime, and the hijack is
worth keeping because it is what makes filtering unbypassable — a television or
phone hardcoded to `8.8.8.8` is answered by our chain anyway. Verified after the
change: `dig @8.8.8.8 an.yandex.ru` from a LAN host returns NXDOMAIN and
`dig @8.8.8.8 example.com` returns the real address, both by way of the router.

The 853 reject was deliberately not reproduced. It made every third-party DoT
resolver unreachable from the LAN and protected nothing, since a device speaking
to an external encrypted resolver bypasses filtering regardless of port 853.
`1.1.1.1:853` and `9.9.9.9:853` now accept connections from the LAN again, where
both previously refused.

Apply with `fw4 check && fw4 reload`; `fw4 check` renders the ruleset through
nftables' check mode without touching the running system, so never reload
without it passing. The file lives on the overlay, so it survives reboots and
`fw4 restart`, but not a firmware upgrade unless its path is listed in
`/etc/sysupgrade.conf`, which now names this file and no longer the exemption-only
predecessor it replaced.

## Making the LAN use it

What is actually wired, as of 2026-08-26, is the router's `stubby` — not its
general upstream. The router's dnsmasq runs `noresolv=1` with three routes, and
the general one belongs to `mihomo` on `127.0.0.1#12344`, the proxy's own
resolver: it decides what goes through a proxy, so replacing it with honest
local recursion would send blocked destinations direct. A second route sends
`work-parent.example`, `internal-work.example` and `internal-work.example` to `192.168.1.2#5353`, which is
mailcow's bundled unbound container answering with the work network's internal
`10.x` addresses. Neither may be repointed here.

What did move is the work-portal branch: the eight `*.work-parent.example` suffixes that
dnsmasq routes to `stubby` on `127.0.0.1#5453`, whose first upstream is now
`192.168.1.2@853` with `labile.cc` authentication, Cloudflare kept behind
it as an ordered fallback (`round_robin_upstreams=0`, or the "fallback" would
serve half the traffic). Those answers matched Cloudflare's byte for byte
before the switch, apart from which member of a rotation set came first, and
they now carry DNSSEC validation. The uci recipe and the verification are in
`docs/dns-clients.md`.

Pointing dnsmasq's *general* upstream here is still possible in principle —
longest-suffix matching would keep `.lan` and the policy routes winning — but
it would cost the proxy routing above and make the whole network's DNS depend
on this host. It is deliberately not done.

A single client can also be pointed straight at `192.168.1.2` instead. The
`force_dns` redirect does not stand in the way, because same-subnet traffic is
switched rather than routed and `dstnat_lan` never sees it — measured from
`192.168.1.3`, `dig @192.168.1.2 external.lan` returns NXDOMAIN while the router
answers `93.100.194.40` for the same name. That is the whole trade in one
query: a client wired directly to unbound gets an independent, validated,
ECS-free answer and loses `.lan`, the `labile.cc` split-horizon record and the
per-domain VPN routing.

## Verification

```sh
sudo unbound-control -s /run/unbound/unbound.ctl status
sudo unbound-control -s /run/unbound/unbound.ctl list_auth_zones
sudo unbound-control -s /run/unbound/unbound.ctl stats_noreset | grep authzone
ls -lh /var/lib/unbound/root.zone

dig -p 5335 @127.0.0.1 example.com
dig -p 5335 @127.0.0.1 nlnetlabs.nl +dnssec
dig -p 5335 @127.0.0.1 dnssec-failed.org
dig @10.8.0.1 example.com
```

`list_auth_zones` must show `.` with a serial and `root.zone` must be about
2 MB. `num.query.authzone.up` counts the lookups answered from that local copy
instead of from the root servers. The `ad` flag must be present on
`nlnetlabs.nl` and `dnssec-failed.org` must be SERVFAIL; SERVFAIL on *both*
means the router exemption is gone.

Confirming that the exemption stayed surgical: from the server,
`dig @192.0.2.1 example.com` must time out, while the same query from any other
LAN host must still return an answer.
