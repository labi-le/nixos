# SMARTctl exporter: by-id device autodiscovery (server)

## The failure

Every panel on the "SMARTctl Exporter Dashboard" joins a value metric to the
metadata metric with a `group_left`:

```
smartctl_device_temperature{...} * on(instance, device) group_left(interface, serial_number, model_name) smartctl_device{...}
```

`group_left` requires exactly one right-hand series per `(instance, device)`
group. A 2026-09-22 reboot renamed the SATA disks — the Netac SSD moved from
`sdb` to `sdc`, the 4 TB Seagate from `sdc` to `sdb` — so for the length of
Prometheus' staleness window there were two `smartctl_device` series sharing
`device="sdb"`: one with the old serial, one with the new. Verified against
the live Prometheus:

- range 16:50–17:20 (contains the reboot), step 60: `ERROR found duplicate
  series for the match group {device="sdb", instance="127.0.0.1:9634"} on the
  right hand-side of the operation`
- last 1h, step 60: `OK series=3`
- last 24h, step 300: `OK series=5` — the coarse step happens to skip the
  overlap, which is why the failure looked intermittent rather than constant

The exporter, the scrape, and the dashboard file itself were all healthy
throughout: `up{job="smartctl"}` had no gaps over 6h and all four drives kept
reporting. The dashboard failed only for time ranges that sampled the
overlap window — and would fail again on every future reboot that shuffles
`/dev/sdX` letters, since Linux does not guarantee SATA enumeration order is
stable across boots.

## The fix

Kernel-letter autodiscovery (`--smartctl.scan`) is unacceptable on this host:
SATA enumeration order is not guaranteed stable across boots, and the
`sdb`/`sdc` swap above proves it swaps in practice, not just in theory. A
static `services.prometheus.exporters.smartctl.devices` list (four hardcoded
`/dev/disk/by-id/...` paths, commit `7b02a8f`) fixed that but traded away
autodiscovery entirely: a drive attached after that commit was invisible to
both the dashboard and the `storage-smart-failure` alert until someone
hand-edited this file.

Both properties are available at once by enumerating `/dev/disk/by-id/`
every time the unit *starts*, instead of doing either at Nix-eval time
(static list) or at exporter-runtime scan time (`--smartctl.scan`).
`systemd.services.prometheus-smartctl-exporter.serviceConfig.ExecStart` is
overridden with `lib.mkForce` to run a `pkgs.writeShellScript` wrapper
(`smartctlDeviceScript` in `modules/grafana.nix`) that lists
`/dev/disk/by-id/`, resolves and deduplicates the entries (next section),
and `exec`s the real `smartctl_exporter` binary with one
`--smartctl.device=<by-id path>` per physical disk found, plus
`--web.listen-address` and `--smartctl.interval` read from
`config.services.prometheus.exporters.smartctl` so the script cannot drift
from the module's own `port`/`maxInterval`. A by-id name is unique and
stable per physical disk for as long as that disk is attached, so two
drives can never trade device labels again and the duplicate match-group is
impossible by construction — while a disk that did not exist when
`7b02a8f` was written is picked up automatically the next time the unit
starts, with no Nix edit required:

```
smartctl_device_temperature{device="ata-Netac_SSD_2TB_AA0202311172T2132225",temperature_type="current"} 36
smartctl_device_temperature{device="nvme-Patriot_M.2_P300_512GB_P300WCBA25041508682",temperature_type="current"} 55
```

(measured by running the exporter binary by hand against `/dev/disk/by-id/`
paths on a spare port).

## Deduplicating by-id aliases

A physical disk has one to three `/dev/disk/by-id/` aliases pointing at the
same kernel device, so a naive "pass every by-id entry" would emit several
`--smartctl.device` flags for one drive — several `smartctl_device*` series
under different `device` labels for what is really one disk. Enumeration on
this host shows the shape of the problem: each target on the right has one
to three aliases on the left, and the NVMe drive has three:

```
/dev/nvme0n1  <-  nvme-Patriot_M.2_P300_512GB_P300WCBA25041508682
/dev/nvme0n1  <-  nvme-Patriot_M.2_P300_512GB_P300WCBA25041508682_1
/dev/nvme0n1  <-  nvme-nvme.10ec-5033303057434241323530343135303836383-5061747269...-00000001
/dev/sda      <-  ata-ST2000DM008-2UB102_ZFL5JZ53
/dev/sda      <-  wwn-0x5000c500e365de40
/dev/sdb      <-  ata-ST4000DM004-2CV104_Z9703DGK
/dev/sdb      <-  wwn-0x5000c50002538718
/dev/sdc      <-  ata-Netac_SSD_2TB_AA0202311172T2132225
```

The script skips `*-part*` entries (partitions, not whole disks), resolves
every remaining name with `readlink -f`, and groups by the resolved target.
Within a group exactly one alias survives, picked by a fixed tier order
(lower tier wins) rather than by the order `ls` happens to return, which
`sort` normalizes before the loop ever sees it and which is not itself a
meaningful tiebreaker:

1. `ata-*` / `nvme-*` (excluding tiers 4 and 5 below) — the human-readable
   name, because it is what an operator recognizes in a dashboard or alert
   without cross-referencing a serial number.
2. `wwn-*` — used only when a target has no human-readable alias. A WWN
   link needs `ID_WWN_WITH_EXTENSION`, which on a USB-attached disk
   requires the bridge to expose ATA/SAT passthrough, so most USB
   enclosures do not get one; this tier mainly covers SATA/SAS disks
   whose `ata-*`/`nvme-*` alias is for some reason missing.
3. `usb-*` / `scsi-*` — the aliases udev's `60-persistent-storage.rules`
   creates for USB (`usb-$env{ID_USB_SERIAL}`) and SCSI/SAS
   (`scsi-$result`) disks. Without this tier a USB disk whose only alias
   is `usb-*` (the common case, since it usually has no `wwn-*` either —
   see tier 2) matched no arm and was silently dropped: enumerated, not
   monitored, no error. Ranked below tiers 1-2 because it is the least
   human-readable identifier that is still specific to one physical disk.
4. `nvme-nvme.<hex>` / `nvme-eui.<hex>` — the raw NVMe identify string
   udev also emits alongside the human-readable `nvme-<model>_<serial>`
   name. The same udev rule emits either shape depending on drive: this
   host's Patriot reports `ID_WWN` as `nvme.<vendor>-<serial>`, but most
   NVMe drives (Samsung, WD, Micron, Crucial, Intel) report EUI64 and so
   get `nvme-eui.<hex>` instead — both are grouped in one tier so neither
   shape can tie with the tier-1 human-readable alias for the same
   target. Carries no more information than tier 1 and is far less
   readable, so it is only used as a last resort if nothing else resolved
   for that target.
5. Anything matching `ata-*_1` / `nvme-*_1` — the `_1`-suffixed duplicate
   the kernel emits for some NVMe controllers alongside the plain name for
   the same disk; rejected in favor of the unsuffixed tier-1 alias when one
   exists, and kept as an absolute last resort rather than dropped outright
   so a target with only a suffixed alias is still monitored.

A tie inside one physical disk's alias set is reachable, not merely
theoretical: `60-persistent-storage.rules` can emit both
`disk/by-id/scsi-$result` and `disk/by-id/$env{ID_BUS}-$env{ID_SERIAL}`
(itself `scsi-<serial>` when `ID_BUS="scsi"`) for the same SAS disk, and
both land in tier 3. The tier order alone does not resolve that case — the
deciding factor is that the enumeration is sorted (`sort`, `LC_ALL=C`)
before the loop runs and the comparison is a strict `<`, so of two aliases
tied on tier the one that sorts first alphabetically is kept and every
later tied alias is rejected, deterministically and identically on every
boot.

On this host every one of the four physical disks has a tier-1 alias, so
the selection is exactly the four paths `7b02a8f` hardcoded — this change
is behaviour-preserving here and only changes behaviour when a disk is
added or removed. The four selected paths are then emitted sorted (`sort`,
`LC_ALL=C`) so the argument order, and therefore which series appear first
in `--help`/logs, is identical on every boot.

An alias matching none of the five tiers above (`virtio-*`, `cciss-*`,
`mmc-*`, `pmem-*`, `ieee1394-*`, `memstick-*`, or any other family udev
may add later) is not silently dropped: the catch-all arm logs
`smartctl-exporter-devices: skipping $name -> $target (unrecognized by-id
alias family, no SMART tier assigned)` to the unit's journal and moves on.
It is deliberately not assigned to a tier and therefore not monitored,
since several of those families (`virtio-*`, `mmc-*`) name buses that
don't support SMART at all — but the operator now has a journal line
naming the disk instead of a disk that vanishes from monitoring with no
trace.

## Hot-plug and hot-removal

Enumeration happens once, when the unit starts — it does not rescan while
running (matching the removed `--smartctl.rescan`, see below). A disk
attached while the machine is already up would therefore be invisible
until the next reboot without help, so `services.udev.extraRules`
(`modules/grafana.nix`) carries a second rule alongside the existing NVMe
group-handover rule: `ACTION=="add"` on a whole `SUBSYSTEM=="block"` disk
(`ENV{DEVTYPE}=="disk"`, excluding `loop*`/`zram*`/`dm-*` (not physical
disks), `sr*` (optical), `md*` (software RAID arrays), and `zd*` (ZFS
zvols — this host runs ZFS and ships `60-zvol.rules`) — none of which can
produce a `--smartctl.device` argument, so none of them should be able to
restart the exporter and race a real scrape into a data gap that pages
`storage-smart-failure`) runs `smartctlDispatchScript`
(`modules/grafana.nix`), a small wrapper that reads the unit's
`ActiveState` and dispatches on it rather than unconditionally
`try-restart`ing:

- `failed` → `systemctl reset-failed` then `systemctl start --no-block`.
  This is the case a plain `try-restart` cannot reach — see below.
- `active` / `activating` / `reloading` → `systemctl try-restart
  --no-block`, the same behaviour the old rule had for a running unit.
- anything else (`inactive`, `deactivating`, …) → no-op, so a unit an
  operator stopped on purpose (`systemctl stop`) stays stopped; the rule
  must not resurrect it.

The dispatch on state exists because the zero-device guard and this rule
compose into a trap that a plain `try-restart` cannot escape. `try-restart`
is documented to do nothing if the unit is not running, and "not running"
includes `failed` — so on a host that briefly has zero disks under
`/dev/disk/by-id` (or whose only disks produce an unrecognized by-id
family, see the tier table above), the wrapper's `exit 1` combines with
`Restart=always`/`RestartUSec=100ms` and the finite `startLimitIntervalSec`/
`startLimitBurst` below to park the unit in `failed`. Once there, the old
rule's `try-restart` was a permanent no-op: the very `add` event for the
disk that just appeared — the one event that would fix the zero-device
condition — could no longer bring the exporter back, and only a manual
`systemctl reset-failed && systemctl start` (or another `nixos-rebuild
switch`) would. `smartctlDispatchScript` closes that gap by checking
`ActiveState` itself and using `reset-failed`+`start` specifically for
`failed`, while still leaving a unit that is cleanly `inactive` (stopped by
an operator, not by the start-limit) alone.

If the unit is `failed` for a reason that is not "zero devices right now"
— a real SMART/hardware fault the exporter can't recover from by
restarting, for instance — the next `add` event still revives it, since
the dispatch script does not distinguish *why* the unit failed, only that
it is `failed`. An operator who wants to leave it down for diagnosis
should `systemctl stop prometheus-smartctl-exporter.service` (which the
dispatch script's `inactive` no-op branch respects) rather than relying on
it staying `failed`, and should check `journalctl -u
prometheus-smartctl-exporter` for the underlying cause before restarting.
Because a multi-bay enclosure, an HBA rescan, or a plain
`udevadm trigger --action=add` over the block subsystem (the NVMe
activation script above already does this for the nvme subsystem) can
fire several `add` events within systemd's default rate-limit window
(measured: an eight-event udev storm from one `udevadm trigger`), the unit
raises the default rate limit to `startLimitIntervalSec = 60;
startLimitBurst = 50;` — generous enough to absorb that storm as
legitimate restarts, but finite. An unbounded limit was tried first and
rejected: the wrapper's own zero-device guard (`exit 1` when nothing
matches any tier, see above) combines with the upstream unit's
`Restart=always`/`RestartUSec=100ms` into an ~10Hz restart loop on an
empty or missing `/dev/disk/by-id`, or a host whose disks only produce
`virtio-*`/`mmc-*` names; with no rate limit that loop runs forever
without ever reaching `failed`, invisible to `systemctl --failed` and to
the `node_systemd_units{state="failed"}` panel, and floods the journal.
A finite `startLimitIntervalSec` parks the unit in `failed` after
`startLimitBurst` restarts instead — and `reset-failed` clears systemd's
start-limit counter along with the failure, so the dispatch script's
revival on the next real `add` event gets the unit a fresh burst budget
rather than being immediately re-rate-limited. A disk removed while the
exporter is running needs no equivalent rule: it simply stops appearing in
`/dev/disk/by-id/` and is not re-enumerated until the next unit start, at
which point its series just stop updating in Prometheus.

## `--smartctl.rescan` removed — now dead

`extraFlags = [ "--smartctl.rescan=2m" ]` was dropped. The exporter's own
`--help` (v0.14.0) states explicitly for `--smartctl.rescan`: *"If any
devices are configured with smartctl.device also no rescanning takes
place."* The wrapper always generates at least one `--smartctl.device=`
flag (it refuses to start with zero, see the hot-plug section above) and
`--smartctl.scan` defaults to disabled once any `--smartctl.device` flag
is present (`--[no-]smartctl.scan ... This is a default if no devices are
specified`) — not because of the now-forbidden `services.prometheus.
exporters.smartctl.devices` option, but because of the flags the wrapper
itself puts on the command line. Both scanning and rescanning are dead
code paths under the wrapper's generated device list, so the flag no
longer does anything and was removed rather than kept as a no-op.

## `devices` / `extraFlags` no longer silent no-ops

`systemd.services.prometheus-smartctl-exporter.serviceConfig.ExecStart` is
`lib.mkForce`d wholesale to the autodiscovery wrapper, which builds its own
`--smartctl.device=` list from `/dev/disk/by-id/` — the nixpkgs module's
usual argv construction, including anything it would have put in
`services.prometheus.exporters.smartctl.devices`, never runs. Leaving
`devices` settable but ignored would make a future re-pin of a disk
(`devices = [ "/dev/sdX" ];`) evaluate cleanly and silently do nothing, so
`modules/grafana.nix` asserts `smartctlCfg.devices == [ ]` and fails the
build with a message pointing at this file if it is ever set again.
`extraFlags` is forwarded verbatim into the same `exec` line ahead of the
generated `--smartctl.device=` flags, and `smartctl_exporter --help`
(v0.14.0) documents `--smartctl.device` as repeatable, so
`extraFlags = [ "--smartctl.device=/dev/sdb" ]` would otherwise evaluate
cleanly, bypass the `devices` assertion entirely, and reintroduce exactly
the unstable kernel-letter `device` label this change exists to make
impossible. The assertion therefore also rejects any `extraFlags` entry
that is exactly `--smartctl.device` or starts with `--smartctl.device=`:
`smartctlCfg.devices == [ ] && !(lib.any (e: e == "--smartctl.device" ||
lib.hasPrefix "--smartctl.device=" e) smartctlCfg.extraFlags)`. The
assertion is anchored to the `=` separator (and the bare space-separated
form kingpin also accepts) rather than a plain prefix match, because a
plain `lib.hasPrefix "--smartctl.device"` also matches
`--smartctl.device-exclude` and `--smartctl.device-include` — two real
`smartctl_exporter --help` (v0.14.0) flags that only affect automatic
scanning, which the wrapper's generated device list already disables, so
setting either through `extraFlags` is a harmless no-op that the
assertion must not reject.
Every other `extraFlags` entry (it can't specify a device list through any
other flag) stays live and is forwarded unchanged.

## `storage-nvme-media-errors` filter drop (commit `7b02a8f`)

Before commit `7b02a8f` ("monitoring: pin smartctl devices by id") the
alert's `increase(smartctl_device_media_errors{...})` expression filtered
on `device="nvme0"`, the kernel-letter label the static device list
produced at the time. That commit — not this change, which does not touch
`modules/monitoring/storage.nix` — switched the device list to by-id paths,
making the NVMe drive's `device` label
`nvme-Patriot_M.2_P300_512GB_P300WCBA25041508682` instead of `nvme0`, so a
filter still pinned to `nvme0` would have silently stopped matching any
series and the alert would never have fired again. `7b02a8f` dropped the
filter rather than rewriting it to track the new by-id label:
`smartctl_device_media_errors` is emitted only for NVMe devices (SATA/SCSI
SMART attributes have no media-error-count field), so the metric was
already NVMe-only without a device filter.

## One-off cleanup: 2026-09-22 label migration series deletion

The reboot on 2026-09-22 renamed the SATA disks (`sdb` → `sdc`, `sdc` → `sdb`),
leaving 677 orphaned `smartctl_*` series with device labels `sda`, `sdb`, `sdc`,
and `nvme0` from autodiscovery runs before the switch. These series took months
to age out under the default 30d retention, during which any dashboard query over
a range longer than ~1 day contained the overlap period and failed with
`found duplicate series for the match group`.

Rather than wait for retention, the `services.prometheus` admin API was enabled
temporarily (`extraFlags = [ "--web.enable-admin-api" ]`) and the following
operations were run:

```
# Delete orphaned series with the old autodiscovered device labels
curl -X POST http://127.0.0.1:3020/api/v1/admin/tsdb/delete_series \
  -d 'match[]=smartctl_device{device=~"sda|sdb|sdc|nvme0"}' \
  -d 'match[]=smartctl_device_attributes{device=~"sda|sdb|sdc|nvme0"}' \
  -d 'match[]=smartctl_device_media_errors{device=~"sda|sdb|sdc|nvme0"}' \
  -d 'match[]=smartctl_device_power_cycles{device=~"sda|sdb|sdc|nvme0"}' \
  -d 'match[]=smartctl_device_power_on_hours{device=~"sda|sdb|sdc|nvme0"}' \
  -d 'match[]=smartctl_device_temperature{device=~"sda|sdb|sdc|nvme0"}'

# Remove tombstones from TSDB (compact to disk, not just in-memory)
curl -X POST http://127.0.0.1:3020/api/v1/admin/tsdb/clean_tombstones
```

Both operations returned 204. After this, the dashboard's `group_left` join
succeeded over every time range (1h, 24h, 7d: 4 series each), and no old-label
samples remained in the last 24h.

**Critical**: The admin API allows deleting arbitrary series and wiping the TSDB
over plain HTTP with no authentication. Prometheus listens on `0.0.0.0:3020` on
this host, so it was disabled immediately after cleanup (`extraFlags` line
removed) and MUST never be left enabled in production.
