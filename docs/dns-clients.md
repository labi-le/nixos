# DNS clients for `labile.cc`

The resolver on `server` exposes two encrypted endpoints. Both front the same
validating recursive resolver as plain DNS does, and both present the publicly
trusted ZeroSSL certificate already issued for the apex name `labile.cc`, so
clients need no custom CA and no SPKI pin.

| Endpoint | Address | Reachable from | Transport |
|---|---|---|---|
| DoT | `labile.cc:853` (`192.168.1.2` on LAN, `10.8.0.1` on VPN, the public address from anywhere) | anywhere | DNS over TLS, RFC 7858 |
| DoH | `https://dns.labile.cc:8443/dns-query` (`192.168.1.2:8443` on LAN, `10.8.0.1:8443` on VPN) | anywhere | DNS over HTTPS, RFC 8484 |

Since 2026-09-07 this is a **deliberately open resolver**. The router forwards
`tcp/853` and, since 2026-11-08, `tcp/8443` from the WAN to the server, and
`access-control` ends in `0.0.0.0/0 allow`, so any client that can reach either
name can resolve through it, roaming devices included. There is no token and no
allowlist: DoT has no path in which to put a secret, and DoH's `/dns-query` is
the same string for every client, so it is a convention rather than a
credential.

Two consequences follow, and both are decisions rather than oversights. Ad and
tracker filtering applies to public clients too — a stranger gets the
household's blocklist, so a false positive looks to them like a site that does
not exist. And the cache is shared, which makes the endpoint a cache-snooping
oracle and lets sustained unique-name traffic evict entries the household
depends on. `docs/dns-resolver.md` covers both, plus the per-client limits that
accompany the exposure.

Plain DNS is **not** offered outside the VPN. It lives on `10.8.0.1:53` only;
the `192.168.1.2:53` listener was removed once measurement showed its only users
were the host's own diagnostics — the LAN reaches this resolver through the
router's `stubby` over DoT, and 92.5 % of all queries already arrived over TLS.
`enp37s0` no longer opens 53 at all, which is what keeps an open ACL from
turning this host into a UDP amplifier. On the server itself, use
`dig @127.0.0.1 -p 5335`; `dig @192.168.1.2` now answers `connection refused`.

DoH came back on 2026-11-08 at `https://dns.labile.cc:8443/dns-query`, and it is
not the arrangement that was removed on 2026-08-26. That one was
`services.doh-server` behind Angie on `443`; this one is unbound's own listener,
because a reverse proxy cannot carry it: unbound drops any connection that does
not negotiate ALPN `h2`, while Angie speaks HTTP/1.1 to its upstreams. The
port is `8443` for that reason, and `dns.labile.cc` lives in the apex
certificate's SAN rather than in a certificate of its own, since unbound reads a
single key pair for every TLS listener.

Two consequences of that shape matter to clients. The listener speaks RFC 8484
wire format only — `?name=example.com&type=A` returns 404, because unbound has
no JSON API — and the port now matters. A client left on the old
`https://dns.labile.cc/dns-query` without `:8443` finds no vhost for that name
on `443`, so it fails certificate validation against whichever default vhost
answers; on port 80 the same path is the ACME stub and returns 404.

One piece of history worth knowing, because it explains why the router's stubby
was dead weight for so long: until 2026-08-26 no LAN host could reach any
third-party DoT resolver, since the router's `adblock-fast` ran
`force_dns_port='53' '853'` and treated the two ports differently — port 53
redirected into its own dnsmasq, port 853 sent to `jump handle_reject` in
`inet fw4`, which is why the failure was an immediate refusal rather than a
timeout. That package has been removed, its reject rule with it, and
`1.1.1.1:853` now accepts connections from the LAN again. The port-53 redirect
survives as a static nftables file with the server's recursion exempted, so
plain DNS from any device still lands in our filtered chain whatever resolver it
was aimed at; see `docs/dns-resolver.md`. Traffic to `192.168.1.2:853` was never
affected either way, because same-subnet traffic is switched rather than routed
and `dstnat_lan` never sees it.

## Support matrix

| Platform | DoT | DoH |
|---|---|---|
| Android 9+ Private DNS | yes | no, the field takes a hostname and nothing else |
| iOS 14+ / macOS 11+ profile | yes (`TLS`) | yes (`HTTPS` + `ServerURL`) |
| Windows 11 | yes | unverified, see below |
| systemd-resolved | yes | no |
| unbound as a forwarder | yes | no, unbound has no DoH client |
| stubby (OpenWrt/Linux) | yes | no |
| AdGuard Home | yes | yes |
| mihomo and murmur | `tls://host` | `https://host:8443/dns-query` |
| Firefox, Chrome | no | yes, custom URL |
| dig 9.20 or newer | `+tls` | `+https=/dns-query` |

The DoT address formats are in the platform sections below. The DoH ones are a
single URL with a client-specific wrapper, collected under "DoH clients".

Browsers used to be absent from that table because they speak DoH only and
there was no DoH endpoint to offer them. Firefox and Chrome now take the URL in
their own settings; Edge reads the DoH configuration from the operating system
and has none of its own.

The split between the two client shapes matters more than the platform. Clients
that take an explicit address plus a separate name for validation — stubby,
systemd-resolved, an unbound forwarder, the Apple profile — work from anywhere
they can route to `192.168.1.2` or `10.8.0.1`, because the address is configured
and the name is used only for the certificate. Clients that accept a hostname
and nothing else, which is every Android Private DNS field, depend on how that
name resolves for them.

DoH clients are the second shape and one degree worse, because the URL carries
both the name and the port and there is nowhere to put an address instead. They
resolve `dns.labile.cc` first: on the LAN the router's split-horizon record
answers `192.168.1.2`, off the LAN the public record plus the `tcp/8443`
forward reach the same listener, and both paths present the same certificate.
A client whose bootstrap resolver cannot reach the name cannot reach the
endpoint either, which is the only real trap in this configuration.

## DoH clients

One URL, `https://dns.labile.cc:8443/dns-query`, is the whole interface. It is
RFC 8484 over HTTP/2: POST with `application/dns-message` and GET with
`?dns=<base64url>` both work, and the JSON API does not exist here.

**AdGuard Home.** Put the URL in Settings → DNS settings → Upstream DNS
servers:

```
https://dns.labile.cc:8443/dns-query
```

AdGuard Home resolves the hostname through its `bootstrap_dns` list before it
can use the upstream, so a box whose own resolver cannot answer for
`dns.labile.cc` needs a plain resolver listed there. The same URL works as a
domain-scoped upstream, `[/labile.cc/]https://…`, though there is nothing to
scope: this resolver answers every zone.

**mihomo and murmur.** Both take the URL as a plain server string in the same
places:

```yaml
dns:
  default-nameserver:
    - 223.5.5.5
  nameserver:
    - https://dns.labile.cc:8443/dns-query
```

`default-nameserver` exists to resolve the *names of* encrypted resolvers and
must stay an IP or a differently-named encrypted resolver; pointing it at the
same hostname is circular. Leave `prefer-h3` at its default: the listener's DoH
is HTTP/2, and an HTTP/1.1 request to it is dropped rather than answered,
measured.

**Firefox.** Settings → Privacy & Security → DNS over HTTPS → Max Protection →
custom, with `network.trr.uri` set to the URL. Chrome takes the same URL under
Settings → Privacy and security → Use secure DNS → custom.

**Apple.** A variant of the DoT profile in the iOS section below: `DNSProtocol`
becomes `HTTPS` and the address becomes a single `ServerURL` string.
`ServerAddresses` is optional for HTTPS; leave it out so the name is resolved
normally, or fill it in with `192.168.1.2` on LAN-only devices.

```xml
<key>DNSProtocol</key>
<string>HTTPS</string>
<key>ServerURL</key>
<string>https://dns.labile.cc:8443/dns-query</string>
```

**Windows 11.** The DoH template field is the natural home for the URL:

```cmd
netsh dnsclient add encryption server=192.168.1.2 dohtemplate=https://dns.labile.cc:8443/dns-query
```

Whether the Windows DNS client honours a port other than `443` in a template is
not stated in Microsoft's documentation and was not measured here. If the
client ignores the port, it fails rather than falling back, and on that platform
DoT is the working transport — it needs no template.

**Android.** Private DNS is DoT only, so there is no system DoH on Android; an
app that ships its own DoH client is the only way in.

## Android

Private DNS speaks DoT only and its field accepts exactly one hostname — no
port, no path syntax exists at all. Strict mode additionally validates the
hostname against the public trust store.

Settings → Network & internet → Private DNS → "Private DNS provider
hostname":

```
labile.cc
```

This now works on any network, which is new as of 2026-09-07 and is the main
practical gain from opening the listener. The hostname is the same everywhere,
but it resolves to two different addresses and both of them work: on the LAN the
router's dnsmasq carries `address=/labile.cc/192.168.1.2`, so a phone on DHCP
reaches the server directly, while off the LAN the public record
`93.100.194.40` applies and the router forwards `tcp/853` to the same daemon.
Either way the certificate matches, because it is issued for the apex name.

The earlier revisions of this document said the opposite, and the reason is
worth keeping: this resolver recurses honestly and answers the public address
for its own name — measured on `127.0.0.1@5335` — so a VPN client, which
resolves through `10.8.0.1`, gets `93.100.194.40` rather than `10.8.0.1`. That
used to mean strict mode marked the network as having no internet access. Now
the public address answers, so the VPN path works too, just by leaving the
tunnel and coming back through the forward. A client that must stay inside the
tunnel needs one of the explicit-address forms below, with `10.8.0.1` as the
address and `labile.cc` as the name to verify.

Installing a private CA into Android's system store requires root, and no
official documentation describes Private DNS interaction with user-installed
CAs; unverifiable, and moot with a publicly trusted certificate.

## iOS and macOS

The payload type is `com.apple.dnsSettings.managed`, available since iOS 14 /
macOS 11 (deprecated in favour of a declarative equivalent in OS 26+). Save as
`labile-dns.mobileconfig`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>PayloadDisplayName</key>
  <string>labile.cc DNS</string>
  <key>PayloadIdentifier</key>
  <string>cc.labile.dns</string>
  <key>PayloadOrganization</key>
  <string>labile.cc</string>
  <key>PayloadRemovalDisallowed</key>
  <false/>
  <key>PayloadType</key>
  <string>Configuration</string>
  <key>PayloadUUID</key>
  <string>2F6E5C4A-9B31-4D87-A1F2-0C5D7B8E3A61</string>
  <key>PayloadVersion</key>
  <integer>1</integer>
  <key>PayloadContent</key>
  <array>
    <dict>
      <key>PayloadType</key>
      <string>com.apple.dnsSettings.managed</string>
      <key>PayloadIdentifier</key>
      <string>cc.labile.dns.dot</string>
      <key>PayloadUUID</key>
      <string>B41D93A7-52C8-4E06-9F3B-D82A16C07E54</string>
      <key>PayloadVersion</key>
      <integer>1</integer>
      <key>PayloadDisplayName</key>
      <string>labile.cc DoT</string>
      <key>DNSProtocol</key>
      <string>TLS</string>
      <key>ServerName</key>
      <string>labile.cc</string>
      <key>ServerAddresses</key>
      <array>
        <string>192.168.1.2</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
```

Replace every `PayloadUUID` with fresh values (`uuidgen`). `ServerAddresses` is
mandatory in practice here, not optional: it is what keeps the profile from
depending on how `labile.cc` resolves on the network the device happens to be
on. VPN devices use `10.8.0.1` in that array instead. A signed profile avoids
extra install confirmations; self-signed signatures suffice. Without MDM the
profile applies to Wi-Fi networks, and when installed manually also to cellular.

## Windows 11

Windows requires the server to be pre-registered before any encrypted mode
becomes selectable: only DNS servers present in the known-server list get DoT,
whether via netsh, PowerShell, or the UI dropdown. Register the server once,
then enable the transport globally:

```cmd
netsh dnsclient add encryption server=192.168.1.2 dothost=labile.cc:853 autoupgrade=yes udpfallback=no
netsh dnsclient set global dot=yes
```

Prerequisites and notes:

- The network adapter's DNS server must be `192.168.1.2` for the
  registration to apply; plain DNS on that address stays the fallback
  transport. VPN adapters register separately against `10.8.0.1`.
- Certificates validate against the system store. Neither the DoT-side
  validation behaviour nor whether the CLI accepts an entry carrying only
  `dothost=` and no DoH template is spelled out in Microsoft's documentation;
  both are unverified here, and the first is irrelevant with a publicly trusted
  certificate. If the entry is rejected without a template, the template to give
  it is `https://dns.labile.cc:8443/dns-query`, from the DoH section above.

## systemd-resolved

Strict DoT with SNI; DoH is not supported by systemd-resolved at all — none
of the `resolved.conf` options mention it. `/etc/systemd/resolved.conf.d/labile.conf`:

```ini
[Resolve]
DNS=192.168.1.2:853#labile.cc
Domains=~.
DNSOverTLS=yes
DNSSEC=allow-downgrade
```

`DNSOverTLS=yes` is strict: if the server is unreachable, resolution fails
rather than falling back (`opportunistic` degrades to plaintext). The `#`
suffix supplies both SNI and the certificate-validation name — without it the
certificate would be checked against the bare IP and fail. VPN-only machines
substitute `10.8.0.1:853`.

## NixOS hosts as clients

The most useful configuration for the other machines in this repository
(`pc`, `fx516`, `notebook`): unbound as a forwarding cache in front of the
server over DoT.

```nix
services.unbound = {
  enable = true;
  settings = {
    server.tls-cert-bundle = "/etc/ssl/certs/ca-certificates.crt";
    forward-zone = [
      {
        name = ".";
        forward-tls-upstream = true;
        forward-addr = [ "192.168.1.2@853#labile.cc" ];
      }
    ];
  };
};
```

Hosts that reach the server only over the VPN use
`10.8.0.1@853#labile.cc`. The `#auth_name` part is mandatory: unbound's
documentation states that leaving out the `#` and auth name means *any* name
is accepted, which defeats the point of authenticated encryption. The
certificate chains to a public CA, so the stock CA bundle suffices. Plain 53 is
no longer an alternative for these hosts: the LAN listener is gone, so DoT is
the only form that reaches this resolver from `192.168.1.0/24`, and the same
configuration keeps working when the host leaves the network.

## OpenWrt router

The AX6000 runs `stubby` 0.4.3 (getdns 1.7.3), and as of 2026-08-26 its first
upstream is this server. What it is *not* is the router's main resolver, which
is the mistake to avoid making: dnsmasq keeps `noresolv=1` and three routes,
and only the first belongs to stubby.

```
LAN client → dnsmasq 192.168.1.1:53
  ├─ eight work-portal suffixes  → stubby 127.0.0.1#5453
  ├─ the internal work zones     → 192.168.1.2#5353
  └─ everything else             → mihomo 127.0.0.1#12344
```

The two work branches are named by role rather than spelled out, here and
everywhere else in this repository: it is public, and those suffixes identify
an employer. They exist in exactly one place, the router's own
`/etc/config/dhcp`, which is imperative and not nix-managed; nothing on the
server keeps a second copy, deliberately — see the canary discussion in
`docs/dns-resolver.md`.

Only the stubby branch was moved. The other two must stay: `mihomo` is the
proxy's own resolver and carries the geo-routing decisions, so answering those
queries honestly from a local recursor would send blocked destinations direct
instead of through a proxy; and `192.168.1.2#5353` is mailcow's bundled unbound
container, which returns the work network's *internal* `10.x` addresses because
the authoritative servers answer by source address and the server's path is
inside the work tunnel. A second, hand-written stubby (`/etc/stubby/tiktok.yml`,
`127.0.0.1@5054`) serves mihomo and is likewise none of this file's business.

Because the package is uci-driven (`manual='0'`) it regenerates
`/var/etc/stubby/stubby.yml` on every start, so editing `/etc/stubby/stubby.yml`
changes nothing — that file is only the shipped sample. Configure it through
uci:

```sh
uci add stubby resolver
uci set stubby.@resolver[-1].address='192.168.1.2'
uci set stubby.@resolver[-1].tls_auth_name='labile.cc'
uci set stubby.@resolver[-1].tls_port='853'
uci reorder stubby.@resolver[-1]=0
uci set stubby.global.round_robin_upstreams='0'
uci set stubby.global.idle_timeout='4000'
uci -q delete stubby.global.dns_transport
uci add_list stubby.global.dns_transport='GETDNS_TRANSPORT_TLS'
uci commit stubby
service stubby restart
```

Two of those lines are the whole point. `round_robin_upstreams='0'` makes the
list a priority order rather than a rotation — left at `1`, Cloudflare would
have served roughly half the queries and "fallback" would have meant "half the
time". And dropping `GETDNS_TRANSPORT_UDP` from the transport list is what
makes this DoT at all: with UDP present, stubby degrades to plaintext port 53
whenever TLS fails, and it says so itself — *a Strict Profile only applies when
TLS is the ONLY transport*. The Cloudflare entries stay after ours as the
failure path, which is why removing UDP costs nothing: DoT to `1.1.1.1:853`
works from this router, verified, so the fallback is encrypted too.

`idle_timeout` is the third line that matters, and it is about who closes the
connection first. The server drops an idle DoT session after
`tcp-idle-timeout: 8000` ms so that a public client hands its slot back, while
stubby's default is ten seconds. For two seconds out of every quiet period the
client therefore holds a socket the server has already closed, and a query
landing in that window is written into nothing: one wasted round trip, one
reconnect, and to a user a random stall. Four seconds puts the client strictly
inside the server's window. Measured on the router, the shorter idle costs the
first query after a quiet gap about 10 ms (median 20 to 30 ms) and leaves
steady-state unchanged.

Verified after the change: `Conn opened: TLS - Strict Profile` and
`Verify passed : TLS` against `192.168.1.2` (the ZeroSSL chain validates
against the stock `ca-bundle`, no pinning needed); twelve unique names sent
through `127.0.0.1:5453` all appeared in the server's unbound log from client
`192.168.1.1`, none served by Cloudflare; and with the first upstream pointed
at a black hole, `1.1.1.1` took over after 3.9 s, proving the fallback rather
than assuming it. `uci commit` writes `/etc/config/stubby`, which survives
reboot and sysupgrade.

Do not trust `nc -z` on this box for reachability checks: busybox returns 1
even for ports that are demonstrably open. Nor can a second `stubby -C` be
started while the service runs — it refuses on the pidfile unless left in the
foreground, which is how the isolated tests above were run.

Rollback touches stubby only, since dnsmasq was never changed:
`uci delete stubby.@resolver[0]`, `uci set
stubby.global.round_robin_upstreams='1'`, re-add
`uci add_list stubby.global.dns_transport='GETDNS_TRANSPORT_UDP'` if the old
opportunistic behaviour is wanted back, then `uci commit stubby` and
`service stubby restart`. Work-domain resolution returns to Cloudflare with no
other side effects.

## Verifying a client

From any client with BIND's `dig` 9.20 or newer:

```sh
dig +tls +tls-ca +tls-hostname=labile.cc @192.168.1.2 example.com
dig +tls +tls-ca +tls-hostname=labile.cc @10.8.0.1 example.com
dig +https=/dns-query +tls-ca @dns.labile.cc -p 8443 example.com
dig +https=/dns-query +https-get +tls-ca @dns.labile.cc -p 8443 example.com
```

`+tls` selects DoT and defaults to port 853. `+https=/dns-query` selects DoH
with that path, and `-p` moves it off `443`; the server line in the output names
the transport it actually used, `(HTTPS)` for DoH. `+tls-ca` enables certificate
validation against the system trust store and is not optional in a check: left
out, dig accepted a self-signed listener, measured. `+tls-hostname` fixes the
name checked against the certificate, which DoT needs because the configured
address `192.168.1.2` is not a SAN.

The certificate carries two names, `labile.cc` and `dns.labile.cc`, with no
wildcard SAN, and both listeners serve it, so either name verifies against
either port. What each transport actually uses is the name its clients are
configured with: DoT authenticates as `labile.cc`, DoH as `dns.labile.cc`,
because the URL is the only place a DoH client learns the name from.

DNSSEC correctness reads straight off the answer flags: a successful
validation sets `ad` in the response header. Both transports must return `ad`
for signed names, and `dnssec-failed.org` must return SERVFAIL on both. `ad`
absent everywhere or SERVFAIL on everything indicates a broken path, not a
broken resolver.

Without dig, the endpoint answers a hand-built RFC 8484 query:

```sh
curl -sS --http2 'https://dns.labile.cc:8443/dns-query' \
  -H 'content-type: application/dns-message' \
  --data-binary @query.bin -o answer.bin
```

`query.bin` is a raw DNS message; `-o answer.bin` gets one back. The JSON that
`curl 'https://dns.labile.cc:8443/dns-query?name=example.com'` asks for does not
exist on this listener, and returns 404.

## What direct clients give up

Three things live exclusively in the router's dnsmasq, so any client wired
straight to this resolver loses them:

- `.lan` names, served only by the router.
- the `labile.cc` split-horizon record. The router carries
  `address=/labile.cc/192.168.1.2`, which covers the apex and every subdomain;
  this resolver has no local data at all and recurses honestly, so it answers
  the public `93.100.194.40` for the same name — measured on
  `127.0.0.1@5335`. A direct client therefore reaches
  services the long way round, through the router's NAT reflection.
- the router's per-domain VPN policy routing (`server=/domain/vpn-dns#5353`),
  which steers selected domains through the VPN tunnel.

Clients going through the router's dnsmasq → mihomo → stubby path lose none of
these; only direct-pointing clients do. The recoverable case is a client that
can split by suffix: `SupplementalMatchDomains` in Apple profiles and
`Domains=~lan` style entries in systemd-resolved send listed suffixes back to
the operating system resolver, i.e. to the router, while everything else stays
on DoT. Since the split-horizon name is the apex `labile.cc`, which is also the
DoT authentication name, an excluded suffix there does not break the transport:
the certificate name is checked against the configured `ServerName`, not
re-resolved.
