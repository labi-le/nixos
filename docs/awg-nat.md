# AmneziaWG NAT moved from the container to the host

`modules/awg/compose.nix` runs `amnezia-wg-easy` with `--network=host`, so
`wg0` and its NAT have always lived in the host network namespace — the
container boundary was cosmetic for this purpose. The image's own
`WG_POST_UP`/`WG_POST_DOWN` env vars ran `iptables -t nat ...` inside the
container anyway, and that stopped working the moment `server` moved onto
the mainline 6.18 kernel.

## Why `iptables` cannot do it any more

nixpkgs' 6.18.41 kernel is built with
`# CONFIG_NETFILTER_XTABLES_LEGACY is not set`, so `ip_tables` and
`iptable_nat` do not exist as modules to load — the CachyOS kernel used
before the migration had them, this one never will. Legacy `iptables`
inside the container fails immediately:

```
iptables v1.8.7 (legacy): can't initialize iptables table `nat':
Table does not exist (do you need to insmod?)
```

Switching the container's `iptables` to the nft-backed binary
(`/sbin/iptables-nft`, confirmed present in the image and reporting
`iptables v1.8.7 (nf_tables)` when probed) does not help either, because
the host's `table ip nat` is a hybrid: docker's own rules were written
through iptables-nft, while the VM's rules (`comment
"vm-tap0-dnat-udp5353"`, `comment "vm-tap0-masq"`) are native nft. Any
`iptables` binary, including the host's own v1.8.13, refuses to touch it:

```
table `nat' is incompatible, use 'nft' tool
```

And the image ships no `nft` binary at all, so the rules cannot be issued
correctly from inside the container under any backend.

## The fix

The two rules from `/run/agenix/awg-env` — hairpin DNAT for VPN clients
reaching the server's own public (`external.lan`) address, redirected to
the LAN address `192.168.1.2`, and masquerade for VPN traffic leaving
`enp37s0` — are reproduced on the host in a dedicated table, `table ip
awg`, installed by `systemd.services.awg-nat` (`modules/awg/default.nix`).
A separate table means nothing here collides with docker's or the VM's
rules in `table ip nat`; nothing is added to that shared table.
`environment.WG_POST_UP`/`WG_POST_DOWN` in `modules/awg/compose.nix` are
now pinned to `"true"` — container `-e` flags win over `--env-file`, so
this neutralises the broken commands from the secret without editing it.

The WAN address is resolved at service start, the same way
`modules/nginx.nix`'s `updateNginxIP` does it (`dig +short` against the
local resolver, falling back to the default-route gateway, matching only
a bare IPv4 literal so a resolver error message never reaches `nft`). The
local resolver is `dnsmasq` on `127.0.0.1:53` (`modules/network/dns.nix`),
not `unbound` — `unbound` has `resolveLocalQueries = false`
(`modules/unbound.nix:58`) and cannot answer the `lan` zone at all;
`dnsmasq` forwards `external.lan` to the router at `192.168.1.1`, which is
what actually resolves the lookup. The `@$ROUTER` fallback exists purely
as a backstop for the case where `dnsmasq` itself is down or has no
upstream for the zone.

Unlike `updateNginxIP`, failure to resolve is not silently tolerated: the
masquerade chain is installed regardless, but the unit fails loudly (exit
1). `Restart = "on-failure"` with `RestartSec = 30` retries the whole
script every 30 seconds until `external.lan` resolves and the hairpin
rule gets installed, rather than leaving the failure to sit until the
next manual restart. The nft script uses the `table ip awg` / `delete
table ip awg` / redefine idiom, so re-running the oneshot (restart or a
config change) atomically replaces the table's contents instead of
piling up chains. Table teardown moved from `ExecStop` to `ExecStopPost`
with a `-` prefix: per `systemd.service(5)`, `ExecStop` commands never run
when the service failed to start in the first place, which is exactly the
exit-1 path above. But the same manual page also says `ExecStopPost`
commands "are invoked when a service failed to start up correctly and is
shut down again", so an unconditional `ExecStopPost = "-nft delete table
ip awg"` deleted the masquerade chain it had just installed on every
resolution failure — the opposite of what this document promises.
`ExecStopPost` now runs `awg-nat-teardown` (`pkgs.writeShellScript`),
which reads `$SERVICE_RESULT` — systemd sets it to `success` only for a
clean stop or a restart — and exits 0 immediately for anything else,
leaving the table in place. The `-` prefix on the `ExecStopPost=` unit
line stays regardless, so a delete racing an already-absent table never
fails the unit.

The nft-generation logic — resolve `external.lan`, build the `table ip
awg` / `delete table ip awg` / redefine block, feed it to `nft -f -` — is
factored into its own script, `awg-nat-apply` (also
`pkgs.writeShellScript`), shared by `ExecStart` and a new `ExecReload`.
`systemctl reload awg-nat.service` re-runs that atomic in-kernel replace
without stopping the unit first, so there is no window where `table ip
awg` is absent. A stop/start cycle, by contrast, deletes the table in
`ExecStopPost` and only rebuilds it once `ExecStart` finishes resolving
`external.lan` again — a `dig +short +time=2 +tries=2` round trip that
can take up to ~4 s on the direct query and ~8 s once the `@$ROUTER`
fallback triggers. Connections already open when the gap opens survive
it, since NAT is bound into conntrack on the first packet and the kernel
does not re-evaluate existing conntrack entries against a new ruleset,
but anything opened inside the gap leaves `enp37s0` with an
unmasqueraded `10.8.0.0/24` source address. Reload avoids the gap
entirely, because `nft -f -` replaces the table's contents in one kernel
transaction instead of removing then recreating it.

The masquerade rule is `ip saddr 10.8.0.0/24 oifname "enp37s0" masquerade`,
deliberately narrowed from the secret's own catch-all
(`iptables -t nat -A POSTROUTING -o enp37s0 -j MASQUERADE`, no source
match) to the tunnel's actual address space (`LOCAL_SUBNET=10.8.0.0/24`,
`WG_DEFAULT_ADDRESS=10.8.0.x`) rather than transcribed verbatim. Docker
and the VM carry their own masquerade rules in `table ip nat`, so this
narrowing is about correctness for `table ip awg`, not about avoiding a
collision with them.

A `systemd.timers.awg-nat-refresh` fires hourly (mirroring
`updateNginxIP`'s schedule) and runs `systemctl try-reload-or-restart
awg-nat.service`, with a `-` prefix on `ExecStart` so the trigger
service's own exit code can never fail. A timer that merely started
`awg-nat.service` would be a no-op: `RemainAfterExit = true` means an
already-active oneshot unit is considered started and a plain `start`
does nothing, so refreshing the baked-in WAN/hairpin state after a
DNS/DHCP change still requires an explicit action from a separate
trigger service rather than the timer unit itself — but that action is
`try-reload-or-restart`, not an unconditional `restart`, for two
reasons. First, `systemctl restart` without `--no-block` waits for the
started job and exits non-zero if the start fails; a `dig` failure
during an hourly refresh would otherwise latch `awg-nat-refresh.service`
itself in `failed` for an hour, regardless of `awg-nat`'s own `Restart =
on-failure` / `RestartSec = 30`. Second, `try-reload-or-restart` is a
no-op on an inactive unit, so a deliberately stopped `awg-nat` is not
silently resurrected by the next hourly tick. Because `awg-nat` now has
an `ExecReload`, the common case — the unit already active — takes the
atomic reload path described above; only a genuinely inactive unit falls
back to a full restart.

Ordering: `awg-nat.service` is after `network-online.target` and
`dnsmasq.service` (so `external.lan` has a working resolver to ask), and
`docker-amnezia-wg-easy.service` is extended with `after`/`wants` on
`awg-nat.service` so the NAT rules exist before the tunnel container
starts.

## Rejected alternatives

- **Pin the kernel to 6.12 LTS**, which still builds `ip_tables` /
  `iptable_nat`. Trades a cached, already-built kernel for an older
  series pinned indefinitely, to keep NAT rules that never belonged
  inside the container in the first place.
- **Rebuild 6.18 with `NETFILTER_XTABLES_LEGACY=y`.** Restores the
  missing symbols but forces a local kernel build (no longer served by
  the binary cache) for every future bump, for the same misplaced rules.

Both were rejected in favor of expressing the NAT where it actually lives
— the host network namespace — with the tool the host already uses
correctly for its own nftables-backed rules.
