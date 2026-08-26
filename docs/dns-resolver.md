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
setup for both encrypted transports is in `docs/dns-clients.md`.

## Encrypted transports

DoT is unbound's own, because that needs nothing but `tls-port` and a
certificate. DoH is not, and cannot be: the unbound in this nixpkgs is built
without `libnghttp2` (`unbound -V` reports only libevent and OpenSSL), so its
DoH listener does not exist. `unbound-checkconf` still accepts `https-port`
and `http-endpoint` without complaint, which makes that a silent failure
rather than a build error — do not add those options here. Rebuilding with
`withDoH = true` would not help either: the DoH listener requires ALPN `h2`
unconditionally (`util/netevent.c` sets `http_min_version = http_version_2`
and drops any connection that does not negotiate `h2`), while nginx speaks
HTTP/1.1 to upstreams, so it can never sit in front of it. `services.doh-server`
terminates DoH instead: Angie handles TLS and HTTP/2 on 443, proxies HTTP/1.1
to `127.0.0.1:8053`, and that daemon speaks plain DNS to `127.0.0.1@5335`.
DoH queries therefore reach unbound from `127.0.0.1`, already inside
`access-control`, so no rule had to be widened for them.

DoT stays on the LAN and VPN addresses only. A public DoT listener cannot be
authenticated — the protocol carries no path or token — so it would be an
unlimited open resolver. DoH is public and deliberately open: `/dns-query` on
`dns.labile.cc`, no token, no client restriction. The rate limit at the nginx
layer (`limit_req zone=doh`, 60 r/min per client IP, burst 120) is the only
access control, and it has to live there: DoH queries reach unbound from
`127.0.0.1`, so unbound sees every public client as one address and cannot
rate-limit per IP itself. DoH runs over TCP, so there is no amplification
angle; the accepted cost is that the server's IP resolves queries for anyone
who finds the endpoint, and scanners probing `/dns-query` will find it.

What the open endpoint is hardened against, having been reviewed once it was
live: `location = /dns-query` is an exact match, because a prefix location
proxies `/dns-queryZZZ` to the daemon and turns its backend 404s into
`nginx-scan-404` fail2ban hits. `Access-Control-Allow-Origin` and
`X-Powered-By` are stripped from the response — doh-server sets the former to
`*`, which lets any web page make its visitors query this resolver from
addresses nobody can usefully ban, and the latter names the exact build to
look up CVEs against. `ratelimit: 1000` caps unbound's outbound queries per
target zone: `ip-ratelimit` cannot help here because every DoH query arrives
as `127.0.0.1`, so without it a random-subdomain flood through the open
endpoint would leave this host, not the attacker, as the address a victim's
authoritative servers see and blocklist. Two costs have no fix while one cache
is shared between the public endpoint and private clients: the returned TTL is
the decremented one, which makes the endpoint a cache-snooping oracle telling
strangers what the household resolved and when, and sustained unique-name
traffic evicts entries the LAN depends on. Separating them means a second
unbound instance with its own cache.

Query logging is on: `log-replies` in unbound, `verbose` in doh-server. Only
`log-replies`, not `log-queries` — the reply line carries the client, qname,
type, class, rcode, timing and answer size, so the query line duplicates it at
twice the journal volume. Attribution is split on purpose. unbound sees every
DoH client as `127.0.0.1`, so the honest client address exists only in the
nginx access log, and the two are correlated by timestamp. doh-server's own
`log_guessed_client_ip` is deliberately off: it derives the address from the
first global entry in `X-Forwarded-For`, which the client sets and nginx only
appends to, so an outsider could write arbitrary "this IP looked up that name"
lines into the log. Without the option the daemon logs what nginx put in
`X-Real-IP`, which nginx replaces rather than appends, so the value is
authentic. The DoH location logs through `log_format doh`, which is the
combined format minus `$query_string`, and a second line of defence sits in the
Alloy pipeline, where `stage.replace` rewrites every `?…` in an nginx line to
`?redacted` before it reaches Loki — that one also covers `error.log`, where a
rate-limited request would otherwise deposit its full base64 query. So the
qname lives only in journald, which is size-capped and rotates, while Loki
keeps the address, the verb and the path for 90 days.

Sustained abuse is banned rather than merely throttled: the `nginx-doh-abuse`
jail feeds `nginx-limit-req` restricted to zone `doh` and bans an address for
an hour after 20 rejections in ten minutes, escalating through the global
`bantime.increment`. It is scoped to `port = "https"`, unlike the other nginx
jails, so a false positive costs the client this vhost rather than every port
on the host — and RFC1918 sources are in `ignoreIP`, so LAN and VPN clients
cannot ban themselves. Because `log-replies` and doh-server's `verbose` write
per-query lines, both units carry `LogRateLimitBurst = 3000` per 30 s: without
it an outsider staying inside the request limit could still evict sshd, sudo
and fail2ban history from the 1 GB journal.

One caution for whoever audits this next: `cert.pem` in every ACME directory
shows as `lrwxrwxrwx`, which looks like a world-writable key and is not one. It
is a symlink to `fullchain.pem`, and symlink modes are always 0777 on Linux;
`find -printf %m` reports the link, not the target. The real files are 0640
`acme:dns-tls`. Do not "fix" it with a chmod, which would replace the link.

## Filtering

Ads and trackers are filtered through two RPZ zones, and the filtering applies
to *tagged clients only*: `access-control-tag` marks `192.168.1.0/24` and
`10.8.0.0/24` with the tag `ads`, and both `rpz:` clauses carry `tags: "ads"`.
Loopback is deliberately left untagged, which is the whole point of the split:
`127.0.0.1` is where the public DoH endpoint arrives from, and an open resolver
that answers NXDOMAIN for names that exist is lying to strangers who never
asked for a policy. Measured after deployment, the same name is NXDOMAIN for a
LAN client on plain 53 and over DoT, and NOERROR through
`https://dns.labile.cc/dns-query`.

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
turns it back on, both verified live. Scope expectation: most LAN traffic never
reaches this resolver at all, since the router sends general queries to mihomo
where `adblock-fast` already filters. What this layer actually covers is DoT
clients, VPN clients on `10.8.0.0/24` and the router's stubby branch.

Coverage against Russian analytics, measured from a tagged client: HaGeZi Light
blocked 19 of 24 tested names, Pro blocked 22, and the two local additions make
it 24. Blocked by both tiers are `mc.yandex.ru`, `an.yandex.ru`,
`ads.adfox.ru`, `yandexadexchange.net`, `top-fwz1.mail.ru`, `rs.mail.ru`,
`ad.mail.ru`, `tns-counter.ru`, `counter.yadro.ru`, the Rambler counters,
`adriver.ru`, `dmg.digitaltarget.ru`, `openstat.net` and `spylog.com`; Pro adds
`appmetrica.yandex.ru`, `mc.admetrica.ru` and `ads.vk.com`. Nothing in
`yandex.ru`, `mail.ru`, `vk.com`, `gosuslugi.ru`, `sberbank.ru`, `ozon.ru`,
`wildberries.ru`, `avito.ru`, the work portals or `labile.cc` is affected.

Both transports share one ZeroSSL certificate for `dns.labile.cc`, issued by
the existing HTTP-01 flow. Two non-obvious constraints govern how it is shared:

- `nginx.service` runs as `User=nginx`, not root, so nixpkgs asserts that every
  consumer can read the certificate. Group `unbound` fails that assertion.
  Hence group `dns-tls`, whose members are exactly the `nginx` and `unbound`
  users, plus `SupplementaryGroups` on the unbound unit and
  `reloadServices = [ "unbound" ]` so renewal reaches it through the existing
  `ExecReload=kill -HUP`.
- The DoH `location` was originally an agenix secret included with a glob, so
  a missing file could not stop Angie serving the other twenty vhosts. That
  whole mechanism is gone: the endpoint is open, the `location` is a plain
  `proxyPass` in `modules/nginx.nix`, and the secret, its rule in `secrets.nix`
  and the encrypted file were removed together.

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

The OpenWrt router (`192.168.1.1`, 24.10.4) runs `adblock-fast` with
`force_dns=1` and `force_dns_port='53' '853'`, which installs a redirect through
ubus at the top of `dstnat_lan`:

```
tcp dport 53 counter redirect to :53 comment "!fw4: ubus:adblock-fast[main] redirect 0"
udp dport 53 counter redirect to :53 comment "!fw4: ubus:adblock-fast[main] redirect 0"
```

Every port-53 packet leaving any LAN host — regardless of destination — was
redirected into the router's own dnsmasq. A query sent to `192.0.2.1`
(TEST-NET-1, unroutable) answered in 0 ms with `aa` set, and asking that address
for `external.lan` returned `93.100.194.40`, a record that exists only on the
router. Behind that redirect a recursive resolver cannot work at all: root-zone
AXFR fails, iterative queries never reach the authoritative servers, and the
interceptor answers without an EDNS OPT record and strips RRSIG, so every signed
zone turns bogus and SERVFAILs.

One source address is therefore exempted before `dstnat_lan` runs, in
`/usr/share/nftables.d/chain-pre/dstnat_lan/10-unbound-egress.nft` on the router:

```
ip saddr 192.168.1.2 udp dport 53 counter return comment "unbound egress exempt"
ip saddr 192.168.1.2 tcp dport 53 counter return comment "unbound egress exempt"
```

Apply with `fw4 check && fw4 reload`; `fw4 check` renders the ruleset through
nftables' check mode without touching the running system, so never reload
without it passing. The rule is scoped to one source address, so `adblock-fast`
keeps forcing every other client through the router and no other device changes
behaviour. Roll back by deleting the file and reloading.

The file lives on the overlay, so it survives reboots and `fw4 restart`, but not
a firmware upgrade unless its path is listed in `/etc/sysupgrade.conf`.

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
`192.168.1.2@853` with `dns.labile.cc` authentication, Cloudflare kept behind
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
