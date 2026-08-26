# DNS clients for `dns.labile.cc`

The resolver on `server` exposes two encrypted endpoints. Both serve the same
validating recursive resolver behind them and both present one publicly
trusted ZeroSSL certificate for `dns.labile.cc`, so clients never need a
custom CA or an SPKI pin.

| Endpoint | Address | Reachable from | Transport |
|---|---|---|---|
| DoT | `dns.labile.cc:853` (`192.168.1.2` on LAN, `10.8.0.1` on VPN) | LAN and VPN only | DNS over TLS, RFC 7858 |
| DoH | `https://dns.labile.cc/<TOKEN>/dns-query` | anywhere, TCP 443 through Angie | DNS over HTTPS, RFC 8484 |

`<TOKEN>` is a secret path component held in the agenix secret `doh-location`;
it never appears in this repository. To obtain it, decrypt the `doh-location`
secret, or read `/run/agenix/doh-location` on the server. Everywhere below,
`<TOKEN>` is a literal placeholder to substitute.

Plain DNS on `192.168.1.2:53` and `10.8.0.1:53` stays available unchanged;
the encrypted endpoints are additions, not replacements.

Which endpoint suits whom: DoT fits devices that permanently live in the LAN
or on the VPN — Android phones at home, systemd-resolved boxes, the router's
stubby, unbound forwarders on other NixOS hosts. DoT cannot carry a secret
path, so it is deliberately not exposed publicly: a public listener would be
an open resolver. DoH fits browsers and anything that roams, because it rides
port 443 and works from any network. One network constraint to know: outbound
TCP/853 towards the internet is actively blocked here (`1.1.1.1:853` and
`9.9.9.9:853` refuse connections while `8.8.8.8:443` is open), so third-party
DoT resolvers are unreachable from this network; traffic between LAN hosts is
switched rather than routed and is unaffected.

## Support matrix

| Platform | DoT | DoH | Address format |
|---|---|---|---|
| Android 9+ Private DNS | yes | no | hostname only, no port, no path |
| iOS 14+ / macOS 11+ profile | yes (`TLS`) | yes (`HTTPS`) | DoT: `ServerAddresses` + `ServerName`; DoH: full `ServerURL` |
| Firefox | no | yes | `https://` URL in `network.trr.uri` |
| Chrome / Chromium / Edge | no | yes | URI-template string |
| Windows 11 | yes (`dothost=`) | yes | DoH: `dohtemplate=` URL; DoT: `server=<ip>` + `dothost=<hostname>:<port>` |
| systemd-resolved | yes | no | `IP:port#iface#SNI`, i.e. `IP:port#hostname` |
| unbound forwarder | yes | yes (forward-zones only) | `forward-addr: <ip>@<port>#<auth_name>` |
| stubby (OpenWrt/Linux) | yes | no | `address_data` + `tls_auth_name` |

Only DoH accepts the secret-token path. Pure-DoT speakers (Android, systemd-
resolved, stubby, unbound) have no concept of paths; there secrecy comes from
the hostname itself, which is why DoT stays LAN/VPN-only.

## Android

Private DNS speaks DoT only and its field accepts exactly one hostname — no
port, no path syntax exists at all. Strict mode additionally validates the
hostname against the public trust store.

Settings → Network & internet → Private DNS → "Private DNS provider
hostname":

```
dns.labile.cc
```

Inside the LAN the name resolves to `192.168.1.2`, on the VPN to `10.8.0.1`;
both terminate the certificate correctly. Off those networks the wildcard
resolves to the public address where nothing listens on 853: in strict mode
Android marks the network as having no internet access, in the default
opportunistic mode it silently falls back to cleartext. Roaming Android
devices should therefore turn Private DNS off and use a DoH application
instead (Intra, RethinkDNS), pointed at
`https://dns.labile.cc/<TOKEN>/dns-query`.

Installing a private CA into Android's system store requires root, and no
official documentation describes Private DNS interaction with user-installed
CAs; unverifiable, and moot with a publicly trusted certificate.

## iOS and macOS

Both protocols come from one payload type, `com.apple.dnsSettings.managed`,
available since iOS 14 / macOS 11 (deprecated in favour of a declarative
equivalent in OS 26+). Save as `labile-dns.mobileconfig`:

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
      <string>cc.labile.dns.doh</string>
      <key>PayloadUUID</key>
      <string>B41D93A7-52C8-4E06-9F3B-D82A16C07E54</string>
      <key>PayloadVersion</key>
      <integer>1</integer>
      <key>PayloadDisplayName</key>
      <string>labile.cc DoH</string>
      <key>DNSProtocol</key>
      <string>HTTPS</string>
      <key>ServerURL</key>
      <string>https://dns.labile.cc/&lt;TOKEN&gt;/dns-query</string>
    </dict>
  </array>
</dict>
</plist>
```

Replace every `PayloadUUID` with fresh values (`uuidgen`) and the escaped
`&lt;TOKEN&gt;` with the real token. `ServerAddresses` is optional; when
omitted the system resolves the URL host through ordinary DNS, which keeps
the profile working on any network thanks to the wildcard record. For the
DoT variant swap the inner dict keys:

```xml
<key>DNSProtocol</key>
<string>TLS</string>
<key>ServerName</key>
<string>dns.labile.cc</string>
<key>ServerAddresses</key>
<array>
  <string>192.168.1.2</string>
</array>
```

VPN devices use `10.8.0.1` instead. A signed profile avoids extra install
confirmations; self-signed signatures suffice. Without MDM the profile
applies to Wi-Fi networks, and when installed manually also to cellular.

## Firefox

In `about:config`:

```js
user_pref("network.trr.mode", 3);
user_pref("network.trr.uri", "https://dns.labile.cc/<TOKEN>/dns-query");
user_pref("network.trr.excluded-domains", "lan,labile.cc");
```

Mode `3` is TRR-only; mode `2` tries DoH first and falls back to plaintext.
A user-set `network.trr.uri` takes precedence over rollout heuristics. No
`network.trr.bootstrapAddr` is needed here: unlike a resolver known only
behind a LAN name, `dns.labile.cc` resolves through any ordinary DNS, inside
and outside. Acceptance of a custom path and port in the URI is inferred from
the URL parsing in `TRRServiceBase.cpp` rather than stated verbatim in any
document; irrelevant here since the port is a standard 443.

## Chrome, Chromium, Edge

GUI: Settings → Privacy and security → Security → "Use secure DNS" → With:
custom, paste the URL:

```
https://dns.labile.cc/<TOKEN>/dns-query
```

Managed Linux deployments use policy files instead —
`/etc/chromium/policies/managed/*.json` (Chromium) or
`/etc/opt/edge/policies/managed/*.json` (Edge):

```json
{
  "DnsOverHttpsMode": "secure",
  "DnsOverHttpsTemplates": "https://dns.labile.cc/<TOKEN>/dns-query"
}
```

`secure` forbids fallback to plaintext; `automatic` upgrades when possible
but may leak. If the built-in DNS client was disabled by another policy,
`BuiltInDnsClientEnabled` must be turned back on. Whether the desktop UIs
accept nonstandard ports in manual input is not documented either way
(inferred from the URI-template format); again moot on port 443.

## Windows 11

Windows requires the server to be pre-registered before any encrypted mode
becomes selectable: only DNS servers present in the known-server list get
DoH/DoT, whether via netsh, PowerShell, or the UI dropdown. Register the
server once — the single entry carries both the DoH template and the DoT
host — then enable both globally:

```cmd
netsh dnsclient add encryption server=192.168.1.2 dothemplate=https://dns.labile.cc/<TOKEN>/dns-query dothost=dns.labile.cc:853 autoupgrade=yes udpfallback=no
netsh dnsclient set global doh=yes dot=yes
```

Equivalent PowerShell:

```powershell
Add-DnsClientDohServerAddress -ServerAddress '192.168.1.2' -DohTemplate 'https://dns.labile.cc/<TOKEN>/dns-query' -AutoUpgrade $True -AllowFallbackToUdp $False
```

Prerequisites and notes:

- The network adapter's DNS server must be `192.168.1.2` for the
  registration to apply; plain DNS on that address stays the fallback
  transport. VPN adapters register separately against `10.8.0.1`.
- Certificates validate against the system store. The DoT-side validation
  behaviour is not spelled out verbatim in Microsoft's documentation;
  unverifiable, and irrelevant with a publicly trusted certificate.

## systemd-resolved

Strict DoT with SNI; DoH is not supported by systemd-resolved at all — none
of the `resolved.conf` options mention it. `/etc/systemd/resolved.conf.d/labile.conf`:

```ini
[Resolve]
DNS=192.168.1.2:853#dns.labile.cc
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
        forward-addr = [ "192.168.1.2@853#dns.labile.cc" ];
      }
    ];
  };
};
```

Hosts that reach the server only over the VPN use
`10.8.0.1@853#dns.labile.cc`. The `#auth_name` part is mandatory: unbound's
documentation states that leaving out the `#` and auth name means *any* name
is accepted, which defeats the point of authenticated encryption. The
certificate chains to a public CA, so the stock CA bundle suffices. These
hosts could equally query plain `192.168.1.2:53` — within one switched LAN
the encryption buys little — but the DoT form is uniform across locations
and authenticates who is answering.

## OpenWrt router

The AX6000 already runs `stubby` 0.4.3-r1 (getdns 1.7.3), currently aimed at
Cloudflare `1.1.1.1:853` and therefore dead weight: outbound 853 is blocked.
Repointing it at the server turns it into the encrypted upstream for the
whole network. Replace the existing resolver sections and wire dnsmasq in
front:

```sh
while uci -q delete stubby.@resolver[0]; do :; done
uci set stubby.global.manual='0'
uci add_list stubby.global.listen_address='127.0.0.1@5453'
uci add_list stubby.global.dns_transport='GETDNS_TRANSPORT_TLS'
uci set stubby.global.tls_authentication='1'
uci add stubby resolver
uci set stubby.@resolver[-1].address='192.168.1.2'
uci set stubby.@resolver[-1].tls_auth_name='dns.labile.cc'
uci set stubby.@resolver[-1].tls_port='853'
uci commit stubby
/etc/init.d/stubby restart

uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#5453'
uci set dhcp.@dnsmasq[0].noresolv='1'
uci commit dhcp
/etc/init.d/dnsmasq restart
```

dnsmasq stays the frontend: `.lan` host records and the
`server=/domain/vpn-dns#5353` policy entries live there, and longest-suffix
matching keeps them winning over the general upstream. The compromise is
availability: with `noresolv=1` the entire network's DNS depends on the
server being up. Cheaper insurance than uptime is a second
`list dhcp.@dnsmasq[0].server='<wan-resolver>'` entry as last-resort
fallback, at the cost of leaking some queries unencrypted during outages.

Rollback is symmetric: delete the added resolver section, restore the
previous upstream list, unset `noresolv`, restart both services.

## Verifying a client

From any client with BIND's `dig` 9.20 or newer:

```sh
dig +tls +tls-ca +tls-hostname=dns.labile.cc @192.168.1.2 example.com
dig +tls +tls-ca +tls-hostname=dns.labile.cc @10.8.0.1 example.com
dig +https=/<TOKEN>/dns-query @dns.labile.cc example.com
dig @192.168.1.2 example.com
```

`+tls` selects DoT and defaults to port 853. `+tls-ca` enables certificate
validation against the system trust store; `+tls-hostname` fixes the name
checked against the certificate — without it dig checks the `@server`
address, and `192.168.1.2` does not appear in the certificate. `+https=`
implies TLS and takes the URI path of the DoH endpoint; dig bootstraps
`dns.labile.cc` through the system resolver, so the same command works from
inside and outside the network.

DNSSEC correctness reads straight off the answer flags: a successful
validation sets `ad` in the response header. Both transports must return
`ad` for signed names, and `dig +tls ... dnssec-failed.org` must return
SERVFAIL. `ad` absent everywhere or SERVFAIL on everything indicates a broken
path, not a broken resolver.

## What direct clients give up

Three things live exclusively in the router's dnsmasq, so any client wired
straight to `dns.labile.cc` loses them:

- `.lan` names, served only by the router.
- the `labile.cc` split-horizon record: the server itself returns the local
  `192.168.1.2` inside, but a bypassing client that reaches the wildcard from
  outside sees the public address instead.
- the router's per-domain VPN policy routing (`server=/domain/vpn-dns#5353`),
  which steers selected domains through the VPN tunnel.

Clients going through the router's dnsmasq → stubby path lose none of these;
only direct-pointing clients do. For Firefox the loss is recoverable per
domain: `network.trr.excluded-domains` routes listed suffixes back through
the operating system resolver, i.e. to the router:

```js
user_pref("network.trr.excluded-domains", "lan,labile.cc");
```

That restores local `.lan` answers and the internal view of `labile.cc` while
everything else stays on DoH. Equivalent escape hatches exist elsewhere —
`SupplementalMatchDomains` in Apple profiles, dnsmasq address overrides on
the router — but Firefox is the case where one pref covers both problems.
