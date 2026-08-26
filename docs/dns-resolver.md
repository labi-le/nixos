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

The root zone is transferred by AXFR straight from the root primaries, by
address rather than by name, because resolving a name would be circular for the
zone that provides the names. `for-downstream = false` keeps unbound a resolver
rather than a root server, as RFC 7706 requires, while `for-upstream = true`
makes it answer TLD delegations from the local copy and DNSSEC-validate that
copy first. `fallback-enabled = true` means a failed transfer degrades to
ordinary recursion instead of an outage.

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

Point the router's dnsmasq at unbound as its only general upstream and keep the
suffix rules in front of it:

```
option noresolv '1'
list server '192.168.1.2'
```

Longest-suffix matching means `/domain/vpn-dns#5353` and `.lan` still win, so
policy routing survives. Note that LAN clients cannot reach `192.168.1.2:53`
directly while `force_dns` is on — their queries are redirected to the router
before they leave — so the router is the only sanctioned client. The cost is
that the whole network's DNS then depends on the server being up;
`serve-expired` with `serve-expired-ttl-reset` keeps a stale cache answering for
a day, but a second `list server` as fallback is cheaper insurance.

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
