# The `data` ZFS pool (server)

## Topology

`data` is a single mirror (`mirror-0`) of two 2000398934016-byte (2 TB) disks, referenced by `/dev/disk/by-id` so import survives `/dev/sdX` renumbering:

- `ata-Netac_SSD_2TB_AA0202311172T2132225` — SATA SSD.
- `ata-ST2000DM008-2UB102_ZFL5JZ53` — 7200 rpm SMR (shingled) HDD.

One member is flash, the other is a spinning SMR disk with a wildly different write-latency profile. The tuning below exists specifically to keep that asymmetry from being a performance trap.

## Pool creation properties

Created with:

```
zpool create -o ashift=12 -o autotrim=on -O compression=zstd -O atime=off -O xattr=sa -O acltype=posixacl -O mountpoint=/drive data mirror <ssd-id> <hdd-id>
```

- `ashift=12` — 4K sector alignment for both members; the 2 TB HDD (ST2000DM008) reports 4K physical sectors while the SSD (Netac) reports 512/512 physical/logical sectors. Using `ashift=12` is mandatory: `zpool create` autodetection would have chosen `ashift=9` based on the SSD's geometry, which cannot be changed after vdev creation and would permanently hamper performance on the HDD side. Wrong ashift cannot be fixed without recreating the pool, so it is always set explicitly rather than left to autodetection.
- `autotrim=on` — keeps the SSD's free space TRIMmed continuously instead of via a periodic batch job; a no-op for the SMR member, which ignores TRIM.
- `compression=zstd` — default for all datasets; overridden to `lz4` on datasets whose content is already compressed or latency-sensitive (below).
- `atime=off` — a read no longer costs a write. This matters more than usual here: every atime update is a write, and every write on this pool eventually has to land on the SMR half.
- `xattr=sa` — extended attributes (ACLs, `security.*`) are stored in the dnode's spill block instead of a hidden shadow directory of tiny files, avoiding an extra directory lookup and extra small objects per file.
- `acltype=posixacl` — standard Linux POSIX ACL support, required by several services on this host.
- `mountpoint=/drive` — the pool's own root mountpoint; every child dataset inherits and extends it by relative name (`data/code` → `/drive/code`), so adding a dataset never requires a matching NixOS `fileSystems` entry.

## Datasets

| Dataset | Mountpoint | recordsize | compression | Other | Holds |
|---|---|---|---|---|---|
| `data` | `/drive` | inherited | zstd | `sync=standard` | root, otherwise empty |
| `data/code` | `/drive/code` | 128K | zstd | `sync=standard` | freqtrade container source/state; general-purpose default recordsize, benefits from zstd on source text |
| `data/sync` | `/drive/sync` | 1M | lz4 | `sync=standard` | large, mostly-sequential file transfers; 1M matches large sequential I/O, lz4 is cheap CPU for content that often isn't very compressible |
| `data/state` | `/drive/state` | 16K | lz4 | `logbias=latency`, `sync=disabled` | small, latency-sensitive state (e.g. ChromaDB's SQLite-backed store, bind-mounted from `modules/chromadb.nix`); small recordsize limits read-modify-write amplification on small random writes, `logbias=latency` tells ZFS to route synchronous writes through the ZIL for lower latency instead of optimizing for throughput |
| `data/tmp` | `/drive/tmp` | 1M | lz4 | `sync=disabled` | scratch space, large sequential I/O |

Measured compression ratios from `zfs get compressratio`: pool `data` 1.25x, `data/code` 1.22x (zstd), `data/state` 1.29x (lz4), `data/sync` 1.04x (lz4), `data/tmp` 2.66x (lz4). Only `data/code` runs zstd; the rest use lz4 because their content is already compressed or latency-sensitive. `data/sync` at 1.04x exemplifies why zstd would not pay for large sequential transfers: lz4's 1.04x is the minimal overhead of the algorithm itself.

`sync` is set per-dataset for durability reasons, not compression reasons; see [Durability](#durability-syncdisabled-on-datastate-and-datatmp) below for the full rationale and measurements behind `sync=disabled` on `data/state` and `data/tmp`.

## Performance characteristics that matter operationally

- **Asynchronous writes are cheap for the SMR half.** ZFS batches dirty data into transaction groups (txg, ~5 s by default) and flushes each txg as a large, mostly-sequential write. SMR drives are pathologically slow at small random writes but tolerate large sequential ones reasonably well, so ordinary buffered I/O on this pool does not expose the HDD's shingled-write penalty.
- **Every `fsync` waits on the HDD, for the datasets that still ask for one.** There is no separate log device (SLOG). Synchronous writes (`fsync`, `O_SYNC`, NFS `sync` exports, database commits) must be committed to the pool's own ZIL before returning, and with a mirror vdev that means waiting on the slower member — the SMR disk. `data/code` and `data/sync` still pay this cost; `data/state` and `data/tmp` opt out of it entirely via `sync=disabled` (see [Durability](#durability-syncdisabled-on-datastate-and-datatmp) below). A SLOG would remove the wait for the datasets that keep `sync=standard`, but there is currently no free space on the system NVMe to carve one out without shrinking its ext4 partition offline; this is deferred, not solved.

## Durability: `sync=disabled` on `data/state` and `data/tmp`

`sync=disabled` is set on `data/state` and `data/tmp`; `data/code`, `data/sync` and the pool root keep `sync=standard` (ZFS's default — synchronous writes wait for `fsync`/`O_SYNC` to reach the ZIL before returning). This property lives in pool metadata, not in this repository: a `nixos-rebuild` does not set it, and a pool re-created from scratch needs it re-applied by hand:

```
zfs set sync=disabled data/state
zfs set sync=disabled data/tmp
```

**Why this can't corrupt anything.** ZFS is always crash-consistent regardless of `sync`: a transaction group either lands whole or not at all, a power cut rolls the pool back to the last completed txg, and both mirror halves stay identical. Redundancy (the mirror) protects against a dead disk, never against lost power — that's what `sync` governs instead. `sync=disabled` therefore cannot corrupt the pool and cannot produce torn state; it only widens the window of acknowledged-but-not-yet-committed writes to roughly one txg interval (~5 s), and write ordering is still preserved, so on power loss the dataset rolls back to some consistent point in time, never a mangled one. This is categorically different from, say, disabling barriers on ext4.

**What `fsync` actually buys.** The pool-consistency guarantee above is unconditional and doesn't depend on `sync` at all. What `sync=standard` adds on top is a promise *to the calling application* that a particular write has landed before the call returns — and that promise only matters if something outside the machine is relying on it: an application that has already acknowledged an action to a human or another system, and would need to un-acknowledge it after a rollback. The question per dataset is whether such an external observer exists.

- `data/state` holds ChromaDB's store (a rebuildable vector index — worst case, reindex) and the ngate VM's qcow2 overlay (a guest OS that just replays its own journal after what looks, from inside the VM, like an ordinary power cut). No external observer remembers the last few seconds either way, so `sync=disabled`.
- `data/tmp` is scratch space by definition, so `sync=disabled`.
- `data/code` is the exception and keeps `sync=standard`: it holds freqtrade's `tradesv3.sqlite`, and the exchange remembers positions the bot may have already acknowledged. Losing acknowledged-but-uncommitted trade state here is exactly the external-observer mismatch `fsync` exists to prevent.
- `data/sync` also keeps `sync=standard`; it wasn't part of this change.
- The NFS export in `modules/drive.nix` is already declared `async`, so the server already declines to honour client-side durability requests over NFS — nothing was given up there by this change that wasn't already given up.

**Measurements**, all `dd bs=8k oflag=dsync` on this pool:

| Configuration | Latency per op |
|---|---|
| `sync=standard` (pool default, before this change) | 20.0 ms |
| `sync=standard`, `logbias=throughput` | 19.3 ms — no improvement, ruled out by measurement, not theory |
| `sync=disabled` (`data/state`, after) | 0.003 ms, sustaining 2.7 GB/s |
| `data/code`, still `sync=standard` | 21.3 ms |
| NVMe root, same test, for reference | 0.35 ms |

`/proc/diskstats` during the `sync=standard` run attributes essentially the entire cost to the SMR member: `sda` (ST2000DM008) 704 writes / 7035 ms busy = 10.0 ms/write; `sdb` (Netac SSD) 713 writes / 111 ms busy = 0.16 ms/write. The SMR disk is ~60x slower per synchronous write and is the whole cost of `sync=standard` on this pool.

**Future option: a SLOG.** A dedicated log device would restore the `fsync` guarantee cheaply — the NVMe-root measurement above (0.35 ms) is roughly the ceiling a SLOG on this NVMe could reach. Not done yet: the NVMe (Patriot M.2 P300 512GB) has no free space, since `nvme0n1p2` runs to the end of the disk, and shrinking it needs an offline `resize2fs` from external media. The board (MSI B450M PRO-VDH MAX) has a single M.2 slot, already occupied by that NVMe, and its PCIe x16 slot holds a Radeon RX 6700 XT; its one remaining PCIe slot is free, so a small Optane drive on an M.2-to-PCIe adapter would fit there instead. A non-mirrored SLOG is safe to lose on a modern pool: losing it only costs whatever sync writes were in flight at the moment of loss, never the pool itself.

## Torrents: deliberately single-copy, off the pool

`/torrents/torrents` lives on the separate 4 TB ext4 disk (`/torrents`) and is bind-mounted to `/drive/torrents` (see `modules/drive.nix`) purely so qBittorrent's fastresume files — which embed absolute paths for existing torrents — keep working. The data itself is **not** on the `data` pool and has no second copy. This is intentional: torrent content is independently re-fetchable from swarms, so it doesn't need mirror redundancy or pool space, and keeping it off the pool avoids doubling the SMR write lo...

## Swap must never go on this pool

A ZFS zvol used as a swap device can deadlock the kernel: reclaiming memory under pressure can need to allocate memory inside the ZFS write path (ZIO, ABD) to service the swap-out I/O itself, and on some kernels that circular dependency wedges the whole system. This is a long-standing, still-open upstream issue: [openzfs/zfs#7734](https://github.com/openzfs/zfs/issues/7734). Swap on this host stays exactly where `modules/swap.nix` puts it — zram and a plain file on the root NVMe — never on a ZFS dataset or zvol.

## Scrub scheduling: monthly, 02:30, randomized delay disabled

`modules/zfs.nix` sets `zfs.scrubCalendar = "*-*-01 02:30:00"` (systemd calendar syntax: the 1st of every month at 02:30 local time) and wires it to `services.zfs.autoScrub.interval`. `systemd-analyze calendar '*-*-01 02:30:00'` confirms the next elapse lands at 02:30 local as intended, with about a month between runs.

Upstream's `services.zfs.autoScrub` (`nixos/modules/tasks/filesystems/zfs.nix`) defaults `interval` to `"monthly"` — which systemd expands to the 1st of the month at 00:00:00, already a reasonable time — but then adds `RandomizedDelaySec = "6h"` on top, uniformly distributed between zero and six hours. Left at that default, a scrub that starts calendar-correct at midnight could actually begin as late as 06:00, deep into a workday morning on this host. Picking a night `OnCalendar` alone does not fix this: the randomized delay is applied on top of whatever calendar time is chosen, so `modules/zfs.nix` also forces `services.zfs.autoScrub.randomizedDelaySec = "0"` to make the 02:30 start exact rather than a six-hour window that happens to start at 02:30.

This precision matters specifically because of the SMR member (`ata-ST2000DM008-2UB102_ZFL5JZ53`, see [Topology](#topology) above). A scrub walks the entire allocated space of both mirror halves in essentially random order (it follows the pool's block-pointer tree, not a linear disk offset), and an SMR disk's sequential-write shingling does nothing to help random-order *reads* — its sustained rate under that pattern collapses compared to the SSD. In practice this makes a scrub a multi-hour event on this pool, not a background task that finishes in minutes; letting it start any time up to six hours after midnight risked it running well into business hours.

`Persistent = "yes"` (systemd default, left untouched) means a scrub missed while the machine was off at 02:30 will fire as soon as the unit next runs, i.e. shortly after the next boot — whatever time of day that boot happens to be. The night window above is therefore a target for the normal case, not a hard guarantee: an unattended reboot at 14:00 on scrub day would still start one at 14:00. That tradeoff is intentional — a scrub that runs late is much better than a scrub that silently never runs — but it is worth knowing before treating "it only scrubs at night" as an absolute.

## Storage alerting (`modules/monitoring/storage.nix`)

Eight Grafana alert rules in the `storage` group cover this pool plus `/backup` and the two exporters that watch them (`zfs_exporter` on `127.0.0.1:9134`, node_exporter on `127.0.0.1:3021`, the smartctl exporter on `127.0.0.1:9634`). All route to `telegram-admin`, the same contact point `modules/monitoring/tidal-syncer.nix` uses.

**Pool not ONLINE** (`storage-pool-health`, critical) fires on `zfs_pool_health{pool="data"} > 0` — any state other than the `0` (ONLINE) enum value. `noDataState = "OK"`: a missing health series means `zfs_exporter` itself died, not that the pool is healthy, and that failure mode is the job of `storage-zfs-exporter-down` below. Making this rule quiet on NoData avoids two pages (exporter-down plus a spurious pool-health page) for one root cause, the same reasoning `tidal-syncer.nix` applies between its `reauth` and `down` rules. `storage-pool-filling` shares the same `zfs_pool_*` metric family and the same sibling coverage, so it is also `noDataState = "OK"`.

**Pool filling** (`storage-pool-filling`, warning) triggers at 80% allocated (`zfs_pool_allocated_bytes / zfs_pool_size_bytes`), not 95%: ZFS free-space fragmentation and the metaslab allocator's behavior both degrade well before a pool is nominally full, so 80% is the point where it is still cheap to add space or prune, not the point where it already hurts.

**Root and `/backup` filling** (`storage-root-filling`, `storage-backup-filling`, both warning, threshold 15% free) have no sibling liveness rule for node_exporter, so both stay `noDataState = "Alerting"` — a missing node_exporter series with no other rule watching it needs to page, not go quiet. The root rule matters for a reason beyond ordinary capacity planning: the system NVMe (`docs/nvme.md`) is DRAM-less, and its write path collapses once the controller runs out of pre-erased blocks to write into, so falling free space there is a latent throughput cliff, not just an eventual "disk full" error. `/backup` holds the sole copy of the torrent data (see [Torrents](#torrents-deliberately-single-copy-off-the-pool) above); filling it has no ZFS-side redundancy to fall back on.

**SMART failure** (`storage-smart-failure`, critical) evaluates `smartctl_device_smart_status < 1` across every device the smartctl exporter reports, rather than filtering to one device label. Device letters on this host are not stable — `sdb`/`sdc` swapped across a single reboot — so a device-letter-scoped query would either silently stop matching the drive it was meant to watch or start matching the wrong one after a rename; evaluating the metric unfiltered sidesteps the problem entirely; the fired instance still carries the `device` label, and the alert summary interpolates it (`{{ $labels.device }}`) so the operator knows which device without needing to guess from the letter alone. The summary's `smartctl -a` command interpolates `/dev/disk/by-id/{{ $labels.device }}`, matching the by-id label the exporter has emitted since `7b02a8f` (see `docs/smartctl-exporter.md`) — it used to read `/dev/{{ $labels.device }}`, a path that has not existed since that commit. `noDataState = "OK"` with `for = "2m"`: on 2026-09-23 the host thrashed under memory pressure (MemAvailable 19 GiB → 2.6 GiB, swap to 15.7 GiB, memory PSI full 43%) and the smartctl scrape itself slowed to 11s, producing two gaps in `count(smartctl_device_smart_status)` (17:06:00–17:07:15 and 17:10:00–17:11:15); with the old `noDataState = "Alerting"` and `for = "0m"` that gap alone paged `storage-smart-failure` on all four drives, telling the operator to replace a drive that `smartctl -H` confirmed PASSED with zero reallocated/pending/uncorrectable/CRC counters throughout. A genuinely failed drive keeps reporting `smartctl_device_smart_status` at `0` continuously, so the metric never goes missing on a real failure and `noDataState = "OK"` costs nothing there; `for = "2m"` absorbs one missed scrape interval without absorbing a real failure, which is still overwhelmingly likely to span more than one scrape. Missing data going quiet on this rule is only safe because `storage-smartctl-exporter-down` below now exists to catch the case where the exporter itself is gone, not just slow — the same split `storage-pool-health`/`storage-zfs-exporter-down` already use.

**NVMe media errors growing** (`storage-nvme-media-errors`, warning) uses `increase(smartctl_device_media_errors[24h]) > 0` rather than a static threshold on the raw counter. The `device="nvme0"` filter this expression used to carry was dropped in commit `7b02a8f` (see `docs/smartctl-exporter.md`) once by-id autodiscovery renamed the NVMe drive's `device` label away from the kernel-letter `nvme0`; the metric is emitted only for NVMe devices in the first place, so the metric is already NVMe-only without a device filter. The counter already reads 6 from a pre-existing, un-investigated event; a plain `> 0` on the value itself would have latched the alert permanently on from the day this rule was deployed. `increase()` over a rolling 24h window only fires while the count is still climbing and self-resolves once a day passes with no further growth, which is the actual signal worth paging on.

**Exporter liveness** (`storage-zfs-exporter-down`, warning) is `up{job="zfs"} < 1` with `noDataState = "Alerting"`, mirroring `tidal-syncer-down` in `modules/monitoring/tidal-syncer.nix` exactly: `up` is Prometheus' own scrape result, so a missing series there means the scrape target itself was dropped from the config, which is strictly worse than a failed scrape and must not go quiet. Without this rule, a dead `zfs_exporter` would make `zfs_pool_health` and `zfs_pool_allocated_bytes` simply stop updating, and the pool-health and pool-filling rules above — deliberately quiet on NoData because they expect this rule to catch that case — would say nothing at all.

**Exporter liveness, smartctl** (`storage-smartctl-exporter-down`, warning) is `up{job="smartctl"} < 1` with `noDataState = "Alerting"`, added alongside the `storage-smart-failure` fix above and built the same way as `storage-zfs-exporter-down`: `up` is Prometheus' own scrape result, not exporter-reported data, so a missing series there means the scrape target itself disappeared from the config, strictly worse than a failed scrape, and must not go quiet. Before this rule existed, a dead or hung smartctl exporter had no dedicated signal at all — the only symptom was `storage-smart-failure` going quiet (now, since the fix above) or paging falsely (before it). Its summary says monitoring is blind ("SMART monitoring is blind, not that a drive is failing") rather than implying a drive fault, so an operator paged by this rule reaches for the exporter's systemd unit instead of `smartctl -a`.
