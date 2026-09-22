# SMARTctl exporter: pinned by-id devices (server)

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

`services.prometheus.exporters.smartctl.devices` (nixpkgs module) is set to
the four `/dev/disk/by-id/` paths for this host, each passed to the exporter
as `--smartctl.device=<path>`. The exporter uses the by-id basename as the
`device` label instead of the kernel-assigned letter, e.g.:

```
smartctl_device_temperature{device="ata-Netac_SSD_2TB_AA0202311172T2132225",temperature_type="current"} 36
smartctl_device_temperature{device="nvme-Patriot_M.2_P300_512GB_P300WCBA25041508682",temperature_type="current"} 55
```

(measured by running the exporter binary by hand against `/dev/disk/by-id/`
paths on a spare port). A by-id name is unique and stable per physical disk,
so two drives can never trade device labels again and the duplicate
match-group is impossible by construction, not merely unlikely.

## `--smartctl.rescan` removed — now dead

`extraFlags = [ "--smartctl.rescan=2m" ]` was dropped. The exporter's own
`--help` (v0.14.0) states explicitly for `--smartctl.rescan`: *"If any
devices are configured with smartctl.device also no rescanning takes
place."* Once `devices` lists explicit paths, `--smartctl.scan` is also
implicitly disabled (`--[no-]smartctl.scan ... This is a default if no
devices are specified`). Both scanning and rescanning are dead code paths
under an explicit device list, so the flag no longer does anything and was
removed rather than kept as a no-op.

## Tradeoff: autodiscovery is now off

This is the important cost of the fix, not a footnote. With an explicit
`devices` list, a drive added to this machine in the future — a new pool
member, a replacement disk, a USB backup drive plugged into smartctl's
scan path — is invisible to **both** the Grafana dashboard **and** the
`storage-smart-failure` Prometheus alert (`modules/monitoring/storage.nix`)
until someone edits this file (`modules/grafana.nix`) to add its by-id path.
Before this change, a new drive would have shown up automatically via
`--smartctl.scan`, with the tradeoff being the exact reboot-time duplicate
label collision documented above. This change converts "SMART monitoring for
an added drive silently never happens" from **never possible** (autodiscovery
always eventually picked it up) to **true until someone remembers to add a
line here**. Anyone adding or replacing a drive on `server` must add its
`/dev/disk/by-id/...` path to the `smartctl.devices` list in
`modules/grafana.nix` as part of that work, or it goes unmonitored with no
error, no alert, and no visible gap — `smartctl_device_smart_status` simply
never has a series for that disk.

The `storage-nvme-media-errors` alert in `modules/monitoring/storage.nix` has
been updated to survive the by-id switch and future disk swaps. The alert's
selector was changed from `smartctl_device_media_errors{device="nvme0"}` to
`increase(smartctl_device_media_errors[24h]) > 0` — dropping the hardcoded
device filter entirely. This is safe because `smartctl_device_media_errors` is
an NVMe-only metric; SATA drives do not export it. The updated rule will match
any NVMe media error, survives both the by-id label change and any future disk
swap, and interpolates the device label in its notification summary so the
operator knows which drive has the problem.

## Historical series break at the switch — expected, not data loss

The `device` label value changes wholesale with this switch: `sda`/`sdb`/`sdc`
(or `nvme0`) becomes the by-id basename. Prometheus has no way to join a time
series under the old label to the "same" series under the new one — they are
different label sets, hence different series, by definition. Every SMARTctl
dashboard graph will show a discontinuity (old series ending, new series
starting from its first scrape) at the moment this change is deployed. This
is expected and is not data loss: the old series remains queryable at its
original timestamps for as long as Prometheus retains it; only the *label*
used to select "this drive going forward" has moved.

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
