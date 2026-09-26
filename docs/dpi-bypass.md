# DPI bypass on the router

The OpenWrt box at `192.168.1.1` runs zapret (`nfqws`) and mihomo. Neither is
nix-managed; both are edited in place, so this file is the record.

zapret runs a single `nfqws` with six profiles, matched in order. The one that
carries ordinary web traffic is

```
--filter-tcp=80,443
--hostlist-exclude=/opt/zapret/ipset/zapret-hosts-user-exclude.txt
--dpi-desync=fake multisplit --dpi-desync-split-seqovl=664 ...
```

It desyncs **everything except** the names in that exclude list. A name in the
list gets no bypass at all — which is the whole failure mode below.

## The ISP filters TLS by exact SNI

Not by IP, and not by suffix. Measured 2026-09-26 from `pc`:

| Target | SNI sent | Result |
|---|---|---|
| `18.165.140.41` | `simg-ssl.duolingo.com` | TLS ok, 0.02 s |
| `18.165.140.41` | `d1vq87e9lcf771.cloudfront.net` | handshake timeout, 6 s |
| `18.165.140.41` | `example.cloudfront.net` | TLS alert in 0.02 s — reached the server |
| `52.85.222.97` | `simg-ssl.duolingo.com` | TLS ok, 0.03 s |

The same address answers or hangs depending only on the name in the
ClientHello, and a nonexistent `*.cloudfront.net` name passes, so this is a
list of specific distribution names rather than a block of the CDN.

TCP is never the signal: `connect()` to every one of these addresses succeeds
in 0.01 s. A tool that only checks the port will report the host healthy.

## Why Duolingo lost its audio

Duolingo serves audio from `d1vq87e9lcf771`, `d2pur3iezf4d1j` and
`d1btvuu4dwu627` under `cloudfront.net`, while its API and images come from
names that are not filtered. `cloudfront.net` sat in
`zapret-hosts-user-exclude.txt`, so those three got no desync, their handshakes
hung, and the app ran normally with silent lessons.

Removing that one line and restarting zapret fixes it:

```sh
sed -i 's/^cloudfront\.net$/#cloudfront.net/' \
  /opt/zapret/ipset/zapret-hosts-user-exclude.txt
/etc/init.d/zapret restart
```

Measured immediately after, same three names, same addresses: TLS ok in 0.02 to
0.03 s, all three. Revert by deleting the `#`; `/tmp/exclude.bak` holds the
pre-change file until the router reboots.

Collateral was checked, not assumed: `d3js.org`, `www.imdb.com`, `slack.com`,
`www.reddit.com`, `cdn.jsdelivr.net`, `assets.nflxext.com` and `www.amazon.com`
all still complete TLS with the desync now applied to CloudFront.

Nothing regenerates the exclude list — no cron entry and no update hook
references it — so the edit survives until someone rewrites the file by hand.

## Still broken, same mechanism

`aws.amazon.com` times out in TLS exactly like the audio CDNs did. It matches
`amazon.com`, which is a separate entry in the same exclude list, so it is
excluded from the bypass for the same reason. It was broken before this change
and is untouched by it. Removing that entry would fix it the same way; it was
left alone because nobody asked for it.

## Diagnosing the next one

The symptom to recognise is an application that works while one class of its
content is silently missing. Three commands separate the causes:

```sh
dig +short @192.168.1.1 <host>            # DNS answers, or the blocklist ate it
nc -z <ip> 443                            # TCP opens even when TLS will hang
openssl s_client -connect <ip>:443 -servername <host> </dev/null
```

If the third hangs while the second succeeds, it is SNI filtering. Then check
whether the name, or any suffix of it, is in
`/opt/zapret/ipset/zapret-hosts-user-exclude.txt`.
