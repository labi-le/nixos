# DNS clients for `labile.cc`

The resolver on `server` exposes one encrypted endpoint. It fronts the same
validating recursive resolver as plain DNS does, and it presents the publicly
trusted ZeroSSL certificate already issued for the apex name `labile.cc`, so
clients need no custom CA and no SPKI pin.

| Endpoint | Address | Reachable from | Transport |
|---|---|---|---|
| DoT | `labile.cc:853` (`192.168.1.2` on LAN, `10.8.0.1` on VPN) | LAN and VPN only | DNS over TLS, RFC 7858 |

DoH existed until 2026-08-26 as `https://dns.labile.cc/dns-query` and was
removed as unused. It was the only publicly reachable part of the resolver, and
it cost a separate daemon, a rate-limit zone, a fail2ban jail and a log format
to keep an open endpoint honest. The `dns.labile.cc` name went with it: DoT now
authenticates as `labile.cc`, so no certificate of its own is needed and no
vhost has to exist to answer the ACME challenge. Any client still configured
with the old hostname fails verification rather than falling back — measured,
`openssl s_client -verify_hostname dns.labile.cc` against `192.168.1.2:853`
returns code 62, hostname mismatch, while `labile.cc` returns 0.

Plain DNS on `192.168.1.2:53` and `10.8.0.1:53` stays available unchanged; DoT
is an addition, not a replacement.

Every client of this resolver now arrives from `192.168.1.0/24`, `10.8.0.0/24`
or loopback, so ad and tracker filtering applies to all of them, over plain 53
and DoT alike. The one path that stays unfiltered is `127.0.0.1:5335` on the
server itself, which exists to compare a filtered answer against an honest one;
`docs/dns-resolver.md` covers the mechanism and the kill switch.

Which clients this suits: anything that permanently lives on the LAN or the
VPN — Android phones at home, systemd-resolved boxes, the router's stubby,
unbound forwarders on other NixOS hosts. DoT is not exposed publicly and cannot
be: the protocol carries no path and no token, so a public listener would be an
unlimited open resolver. Devices that roam have no encrypted path to this
resolver at all, because browsers speak only DoH; their options are the
AmneziaWG VPN, which puts them on `10.8.0.1` with both plain 53 and DoT
available, or a third-party resolver with no filtering.

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

| Platform | DoT | Address format |
|---|---|---|
| Android 9+ Private DNS | yes | hostname only, no port, no path |
| iOS 14+ / macOS 11+ profile | yes (`TLS`) | `ServerAddresses` + `ServerName` |
| Windows 11 | yes | `server=<ip>` + `dothost=<hostname>:<port>` |
| systemd-resolved | yes | `IP:port#iface#SNI`, i.e. `IP:port#hostname` |
| unbound forwarder | yes | `forward-addr: <ip>@<port>#<auth_name>` |
| stubby (OpenWrt/Linux) | yes | `address_data` + `tls_auth_name` |

Browsers are absent from that table on purpose: Firefox, Chrome and Edge
implement DoH only, so since the endpoint was removed they can no longer be
pointed here at all. They inherit whatever the operating system resolves,
which on the LAN is this resolver by way of the router.

The split between the two client shapes matters more than the platform. Clients
that take an explicit address plus a separate name for validation — stubby,
systemd-resolved, an unbound forwarder, the Apple profile — work from anywhere
they can route to `192.168.1.2` or `10.8.0.1`, because the address is configured
and the name is used only for the certificate. Clients that accept a hostname
and nothing else, which is every Android Private DNS field, depend on how that
name resolves for them.

## Android

Private DNS speaks DoT only and its field accepts exactly one hostname — no
port, no path syntax exists at all. Strict mode additionally validates the
hostname against the public trust store.

Settings → Network & internet → Private DNS → "Private DNS provider
hostname":

```
labile.cc
```

This works on the LAN and nowhere else, and the reason is worth stating
precisely because an earlier version of this document had it wrong. The LAN
answer comes from the router's dnsmasq, which carries
`address=/labile.cc/192.168.1.2` and so maps the apex and every subdomain to the
server; a phone using DHCP resolves the name that way and reaches
`192.168.1.2:853` with a matching certificate. This resolver itself recurses
honestly and answers `93.100.194.40` for the same name — measured on both
`127.0.0.1:5335` and `192.168.1.2:53` — so a VPN client, which resolves through
`10.8.0.1`, gets the public address, where nothing listens on 853. In strict
mode Android then marks the network as having no internet access; in the default
opportunistic mode it silently falls back to cleartext.

VPN clients therefore need one of the explicit-address forms below, with
`10.8.0.1` as the address and `labile.cc` as the name to verify. Giving Android
the same treatment would require a per-view answer in unbound, which is not
configured. Roaming devices have no encrypted path here at all.

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
  certificate. Should the entry be rejected without a template, there is no
  template to give it any more — use plain DNS on `192.168.1.2` instead.

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
certificate chains to a public CA, so the stock CA bundle suffices. These
hosts could equally query plain `192.168.1.2:53` — within one switched LAN
the encryption buys little — but the DoT form is uniform across locations
and authenticates who is answering.

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
an employer. They live in the agenix secret `dns-canaries` and in the router's
own `/var/etc/dnsmasq.conf.*`, which is not nix-managed.

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
dig @192.168.1.2 example.com
```

`+tls` selects DoT and defaults to port 853. `+tls-ca` enables certificate
validation against the system trust store; `+tls-hostname` fixes the name
checked against the certificate — without it dig checks the `@server`
address, and `192.168.1.2` does not appear in the certificate. The certificate
carries exactly one name, `labile.cc`, with no wildcard SAN, so that is the only
value `+tls-hostname` accepts.

DNSSEC correctness reads straight off the answer flags: a successful
validation sets `ad` in the response header. DoT must return `ad` for signed
names, and `dig +tls ... dnssec-failed.org` must return SERVFAIL. `ad` absent
everywhere or SERVFAIL on everything indicates a broken path, not a broken
resolver.

## What direct clients give up

Three things live exclusively in the router's dnsmasq, so any client wired
straight to this resolver loses them:

- `.lan` names, served only by the router.
- the `labile.cc` split-horizon record. The router carries
  `address=/labile.cc/192.168.1.2`, which covers the apex and every subdomain;
  this resolver has no local data at all and recurses honestly, so it answers
  the public `93.100.194.40` for the same name — measured on both
  `127.0.0.1:5335` and `192.168.1.2:53`. A direct client therefore reaches
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
