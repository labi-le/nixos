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
## Thermal throttling mitigation via APST

### Measurement

At 1 MB/s of sustained writes, the drive operates at 62 °C in PS0 (operational, 8 W). Without a heatsink, observed temperatures reach 100 °C under load; with a heatsink, still 80 °C. The Patriot P300 supports Autonomous Power State Transitions (APST):

- PS0: operational, 8 W (continuous operation)
- PS1: 4 W (tolerable 1-5 ms latency)
- PS2: 3 W (tolerable 20-50 ms latency)
- PS3: 0.03 W non-operational, 5 ms entry + 10 ms exit latency (15 ms round-trip total)
- PS4: 0.005 W non-operational, 54 ms entry + 45 ms exit latency (~100 ms round-trip, firmware-unreliable)

With `nvme_core.default_ps_max_latency_us=0`, the kernel disables APST entirely, keeping the drive in PS0 permanently (`nvme get-feature -f 0x0c` shows `APSTE: Disabled`). This disables power-saving but was the original default to avoid APST firmware bugs that corrupt state or stall I/O.

### Configuration

`modules/kernel-server.nix` sets `nvme_core.default_ps_max_latency_us=15000` to allow the controller to use PS3 (15 ms round-trip latency, 0.03 W consumption) and block PS4 (whose ~100 ms wake time could stall NFS, mail, and cache services, and whose deepest firmware paths are the source of most APST dropout bugs).

The kernel only transitions to a non-operational power state whose entry + exit latency is ≤ `default_ps_max_latency_us`. Setting this to 15000 microseconds balances thermal reduction with latency risk: PS3's 15 ms round-trip is acceptable for this server's workload, while PS4's ~100 ms is not. The upstream default (100000) would allow PS4 and is too aggressive for a synchronously-served NFS mount.

### Regression watch

APST firmware bugs manifest as `nvme nvme0: controller is down; will reset` or `I/O timeout` in `journalctl -k`. Monitor for these messages after the next boot. Recovery is to revert `nvme_core.default_ps_max_latency_us` to `0` in `modules/kernel-server.nix` and rebuild.

## Host Controlled Thermal Management (HCTM)

### Measurement

`nvme id-ctrl /dev/nvme0` reports `hctma: 0x1` (bit 0 set: Host Controlled
Thermal Management supported), `mntmt: 318` K (45 °C, the controller's
minimum manageable temperature), `mxtmt: 393` K (120 °C, its maximum).
Factory feature 0x10 was `0x0175017f`: TMT1 (light throttle) = 373 K =
100 °C, TMT2 (heavy throttle) = 383 K = 110 °C. `nvme smart-log`'s
`Thermal Management T1/T2 Trans Count` were both 0 even after the drive was
observed at 74 °C during a `cargo build` that filled zram and drove swap
writes. To prevent swap-out traffic from heating the NVMe beyond its thermal
throttle points, the 16 GiB `/swapfile` was removed from
`hosts/configuration-server.nix` (via `lib.mkForce [ ]`). Until a dedicated
SATA SSD is added for swap (outside the ZFS mirror, which has an OpenZFS #7734
deadlock with swap), memory pressure beyond zram capacity will trigger the OOM
place as a secondary defense in case the throttle mechanism proves effective,
but this is unverified on this firmware (see Measured effect below).

### Configuration (`modules/nvme.nix`)

Feature 0x10 encodes TMT1 in bits 31:16 and TMT2 in bits 15:0, each in
kelvin. `systemd.services.nvme-hctm` runs
`nvme set-feature -f 0x10 -V 0x01570161` at boot, requesting TMT1 = 343 K =
70 °C and TMT2 = 353 K = 80 °C to the controller (the host's requested
throttle points; whether the firmware acts on them is unknown), keeping the
drive at full speed below 70 °C and comfortably inside the drive's 45–120 °C
manageable range. Feature 0x10 is controller-scoped, not namespace-scoped:
the live test confirmed the controller rejects `set-feature -f 0x10` when
given the namespace block device directly (`NVMe status: Feature Not
Namespace Specific`), so the service resolves the stable
`/dev/disk/by-id/nvme-Patriot_M.2_P300_512GB_P300WCBA25041508682` path to
its namespace block device, then follows `/sys/class/block/<ns>/device` to
the owning controller and runs `id-ctrl`/`set-feature` against that
controller char device (e.g. `/dev/nvme0`). The service checks
`hctma` bit 0 before calling `set-feature`; on a controller without HCTM
support it logs and exits 0 so a future drive swap doesn't fail the boot.

`set-feature` without `-s` (save) only changes the *current* value, which
the controller forgets on a controller reset or power cycle — it does not
persist like a saveable/persistent feature would. The APST tuning in the
section above can itself trigger a controller reset
(`nvme nvme0: controller is down; will reset`), which would silently revert
HCTM back to the factory 100/110 °C thresholds. A `SUBSYSTEM=="nvme"`
udev rule matches `ACTION=="change"` with `ENV{NVME_EVENT}=="connected"` on
`KERNEL=="nvme0"` and runs `systemctl --no-block restart nvme-hctm.service`.
This event is confirmed to fire on every controller reset: the kernel's
`nvme_start_ctrl()` (called at the end of `nvme_reset_work()` in
`drivers/nvme/host/pci.c`) unconditionally emits a `KOBJ_CHANGE` uevent
tagged `NVME_EVENT=connected` on the controller's sysfs device, regardless
of transport — confirmed by reading the running kernel's
(6.18.41) `drivers/nvme/host/core.c` and `drivers/nvme/host/pci.c`.

### Measured effect (2026-09-24)

Feature 0x10 was confirmed at `0x01570161` (TMT1 343 K = 70 °C, TMT2 353 K = 80 °C). The `nvme-hctm` service applied it and the controller accepted it. However, the composite temperature rose above TMT1 during normal operation (72 °C observed 2026-09-24 00:23, 00:38, 00:39, 00:42, 00:46), yet `nvme smart-log` reported `Thermal Management T1 Trans Count 0` and `T2 Trans Count 0` at 02:10, and `T1 Total Time 0`, `T2 Total Time 0`. The NVMe specification increments the T1 transition count each time rising temperature above TMT1 triggers throttling, so either HCTM is accepted but not acted on by this firmware, or the counters are not populated. Throughput cannot settle the question either way: in a 00:05 benchmark, sustained writes swung between 26 and 180 MB/s from SLC-cache folding regardless of temperature. **Conclusion: HCTM on this drive is unverified.** It is retained because it is harmless, but it must not be relied on as thermal protection.

Actual temperature reduction on this host came from:
- APST (62 °C idle before, 55–60 °C after enabling PS3 transitions).
- Removing the 16 GiB `/swapfile` to reduce write-induced heating.

The 69–72 °C plateau from 23:50 to 00:55 on 2026-09-24 was from two write benchmarks and `fstrim` on 181 GiB + 27 GiB of data, keeping the drive 75–95% busy. Once the workload completed around 01:15, temperature fell to 55–60 °C. Residual activity after 01:20 (3–4 MB/s reads at ~10% busy, probably page-cache refaults under memory pressure) limits how often APST can idle the drive.

### Verifying throttles (if re-enabled on a different firmware)

### Reverting

`systemctl disable --now nvme-hctm.service` and power-cycle the drive (a
plain reboot is not enough — TMT1/TMT2 revert only on a controller reset or
power cycle, and disabling the service just stops it from being
re-applied). Alternatively, run
`nvme set-feature /dev/nvme0n1 -f 0x10 -V 0x0175017f` once to restore the
factory 100/110 °C thresholds without waiting for a reset.
