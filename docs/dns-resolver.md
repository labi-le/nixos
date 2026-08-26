# DNS resolver on `server`

`modules/unbound.nix` runs unbound as a validating, recursive resolver with a
local copy of the root zone (RFC 7706). It is a second, independent resolver
that sits *beside* the existing DNS path instead of replacing it.

## Listeners

| Address | Purpose |
|---|---|
| `127.0.0.1@5335` | administration and verification from the host |
| `192.168.1.2:53` | LAN clients and the router, when pointed here explicitly |
| `10.8.0.1:53` | AmneziaWG clients; `modules/awg/default.nix` already accepts `udp/53` on `wg0` |

Port 53 on loopback stays with dnsmasq. `access-control` allows only
`127.0.0.0/8`, `192.168.1.0/24` and `10.8.0.0/24`; everything else is `deny`,
which drops silently and gives no amplification surface. The firewall opens 53
only on `enp37s0` and `wg0`, never globally.

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

## Router-side prerequisite for real recursion

The OpenWrt router (`192.168.1.1`, 24.10.4) runs `adblock-fast`, which installs a
`force_dns` redirect through ubus:

```
chain dstnat_lan {
        tcp dport 53 counter redirect to :53 comment "!fw4: ubus:adblock-fast[main] redirect 0"
        udp dport 53 counter redirect to :53 comment "!fw4: ubus:adblock-fast[main] redirect 0"
}
```

Every port-53 packet leaving any LAN host — regardless of destination — is
redirected into the router's own dnsmasq. Proof: a query sent to `192.0.2.1`
(TEST-NET-1, unroutable) answers in 0 ms with `aa` set, and asking it for
`external.lan` returns `93.100.194.40`, a record that exists only on the router.

Consequences for a recursive resolver behind it:

- root-zone AXFR from `b`, `f`, `k` and `xfr.dns.icann.org` all fail, so the
  RFC 7706 copy is fetched over HTTPS via `auth-zone url:` instead
- iterative queries never reach the real authoritative servers
- the interceptor answers without an EDNS OPT record and strips RRSIG, so
  DNSSEC validation turns signed zones bogus

To let this one host recurse for real, exempt its source address before
`dstnat_lan` runs. On the router:

```sh
cat > /usr/share/nftables.d/chain-pre/dstnat/10-dns-egress-exempt.nft <<'EOF'
ip saddr 192.168.1.2 udp dport 53 counter return comment "unbound egress exempt"
ip saddr 192.168.1.2 tcp dport 53 counter return comment "unbound egress exempt"
EOF
fw4 check && fw4 reload
```

`fw4 check` prints the generated ruleset without applying it; never reload
without it passing first. The rule is scoped to one source address, so no other
device changes behaviour, and `adblock-fast` keeps forcing every other client
through the router. Roll back by deleting the file and reloading.

## Making the LAN use it

Point the router's dnsmasq at unbound as its only general upstream and keep the
suffix rules in front of it:

```
option noresolv '1'
list server '192.168.1.2'
```

Longest-suffix matching means `/domain/vpn-dns#5353` and `.lan` still win, so
policy routing survives. The cost is that the whole network's DNS then depends
on the server being up; `serve-expired` with `serve-expired-ttl-reset` keeps a
stale cache answering for a day, but a second `list server` as fallback is
cheaper insurance.

## Verification

```sh
sudo unbound-checkconf /etc/unbound/unbound.conf
sudo unbound-control -s /run/unbound/unbound.ctl status
sudo unbound-control -s /run/unbound/unbound.ctl list_auth_zones
ls -lh /var/lib/unbound/root.zone

dig -p 5335 @127.0.0.1 example.com
dig -p 5335 @127.0.0.1 nlnetlabs.nl +dnssec | grep -c '\bad\b'
dig -p 5335 @127.0.0.1 dnssec-failed.org
dig @10.8.0.1 example.com
```

`list_auth_zones` must show `.` with a serial. A SERVFAIL on
`dnssec-failed.org` together with the `ad` flag on `nlnetlabs.nl` means
validation works; SERVFAIL on *both* means the router exemption above is
missing.
