# NVMe root drive (`server`)

## Hardware

Drive is a DRAM-less Patriot M.2 P300 512GB. DRAM-less controllers keep the
flash translation layer's mapping tables in host memory (HMB, 64 MiB here)
rather than onboard DRAM, and rely much more heavily on the OS sending TRIM
promptly — without it, every write has no pool of pre-erased blocks to land
in and degrades into read-modify-write garbage collection.

## Incident: write throughput collapse (2026-09-22)

Sustained writes to the ext4 root had collapsed to 32-55 MB/s from the very
first block, with reads unaffected at 841 MB/s. PCIe link was confirmed full
(8 GT/s x4), HMB enabled, power state PS0, zero thermal-throttle transitions,
`critical_warning` 0. Device-wide write accounting matched the test payload
exactly (523 MB moved for a 512 MB `dd`), ruling out a competing writer.

`fstrim -v /` released **132.3 GiB** of untrimmed blocks. Immediately after:

| Test | Before TRIM | After TRIM |
|---|---|---|
| 512 MiB direct write | 32-55 MB/s | 1.7 GB/s (43x) |
| 4 GiB sustained write | (not separately measured) | 606 MB/s |
| Read (unaffected throughout) | 841 MB/s | 841 MB/s |

The drive was doing read-modify-write GC on every write because it had no
free erased blocks left. Temperature tracked the wasted work: 55 C idle vs.
70 C during the pre-TRIM write tests. The user had reported the NVMe
overheating; that heat was largely GC thrash, not the actual workload.

### Root cause

`fstrim.service` last ran to completion on 2026-09-21 00:02:37 and was killed
mid-run — `fstrim.service: Main process exited, code=killed, status=15/TERM`
— by a `nixos-rebuild switch` restarting units underneath it. Upstream
`nixos/modules/services/misc/fstrim.nix` only generates the timer; the
service unit itself ships inside `util-linux` as `Type=oneshot` with no
`Restart=` directive at all, so a SIGTERM mid-run left the unit failed and
nothing retried it — the only remaining trigger was the next `OnCalendar`
tick. `services.fstrim.interval` defaulted to `weekly`, far too rare for
this host's write churn (measured ~258 MB/min from `nix-daemon` during
builds, plus journald and docker), so the untrimmed backlog had a full week
to accumulate before anything would have run TRIM again.

### Fix (`modules/nvme.nix`)

- `services.fstrim.interval = "daily"` — matches the host's actual write
  rate instead of the upstream weekly default.
- `systemd.services.fstrim.serviceConfig.Restart = "on-failure"` with
  `RestartSec = "5min"` — a signal-killed oneshot is treated as failed, so
  this makes an interrupted run recover on its own within minutes instead of
  waiting for the next calendar trigger.
- `systemd.services.fstrim.restartIfChanged = false` — stops a future
  `nixos-rebuild switch` from tearing the unit down mid-run in the first
  place (the proximate cause of this incident); it only needs to pick up a
  changed timer schedule or service definition on the *next* invocation, not
  interrupt one already executing.

## ZFS pool

The `data` pool (`/drive`, see `docs/zfs-pool.md`) needs none of this: it
runs with `autotrim=on`, so its TRIM is continuous and independent of
`fstrim.service`/`fstrim.timer`. This document concerns the ext4 root only.

## Automatic garbage collection

`/nix` holds ~208 GiB. The Grafana alert `storage-root-filling` (root below
15% free) was triggered because `nix-store --gc --print-dead` showed ~95 GiB
of unreferenced paths. Root free space is critical on a DRAM-less NVMe: when
free blocks run low, write speed collapses catastrophically as the controller
has no pre-erased blocks available and must do read-modify-write GC on every
write.

`nix.gc.automatic = true`, `nix.gc.dates = "*-*-01,15 04:00:00"`, `nix.gc.options = ""`,
and `nix.gc.randomizedDelaySec = "1h"` enable automatic garbage collection
without deleting any system generations (empty `options` means no `-d` or
`--delete-older-than` flags, so `nix-collect-garbage` removes only dead paths
referenced by none of the generations). GC runs on the 1st and 15th of each
month and evicts paths pushed to the local cache `https://cache.labile.cc` by
other hosts via harmonia. Clients then miss on the local cache and refetch
evicted paths from `cache.nixos.org` (locally built derivations, like custom
kernels, must be rebuilt). This is the accepted tradeoff for preventing the
NVMe from filling up and collapsing write performance on a DRAM-less controller.
See `docs/nix-reference.md` for cache push details.
