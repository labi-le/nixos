# Netac 2TB NVMe: TRIM wedges the controller (`/mnt/ssd2tb`)

## Hardware

The pc carries a second NVMe drive, a Netac NVMe SSD 2TB (serial
`RN202408202T336555`, firmware `3.S.J.CU`) at `0000:07:00.0`, behind the
`0000:05:00.0` and `0000:06:00.0` bridges. The link trains at Gen4 x4 and the
AER counters stay at zero.

The drive reports PCI vendor `0x1f40`, which is not a registered vendor ID, and
the kernel logs `nvme nvme1: Ignoring bogus Namespace Identifiers` at every
probe for the same reason: the controller reports an all-ones NGUID.

XFS lives on `nvmeXn1p1` (filesystem UUID
`3553b4a1-44a2-4e89-b5b7-f2209e977e3a`) and mounts at `/mnt/ssd2tb` from
`hosts/hardware-pc.nix` with `nofail,inode64,logbsize=256k`. The mount does not
use `discard`, so `fstrim.service` is the only thing that sends TRIM to this
disk.

Device names are not stable: the nvme driver probes asynchronously and the two
drives swap `nvme0`/`nvme1` between boots (seen on 2026-11-28). Match the drive
by model (`Netac NVMe SSD 2TB`) or serial, never by device name.

## Symptom

`/mnt/ssd2tb` vanishes while the machine is up. Every reader gets `EIO`:
syncthing logs `stat /mnt/ssd2tb/sync: input/output error`, Steam asserts on
`statvfs64 failed for /mnt/ssd2tb/SteamLibrary, errno 5`. After that the drive
is gone from the PCIe bus, and boots pass without it until the power is cut
completely.

## Evidence

Five `fstrim.service` runs died at `/mnt/ssd2tb` while `/` and `/boot` trimmed
fine:

| Date | fstrim start | FITRIM fails | First DSM timeout |
|---|---|---|---|
| 2026-11-21 | 20:45:30 | 20:50:24 | 20:46:01 |
| 2026-11-22 | 01:31:48 | 01:36:40 | 01:36:40 |
| 2026-11-23 | 18:34:12 | 18:40:07 | 18:34:43 |
| 2026-11-24 | 17:18:31 | 17:24:26 | 17:19:02 |
| 2026-11-27 | 01:24:14 | 01:29:06 | 01:24:45 |

Before that the same job trimmed the filesystem daily without errors. The last
clean run was 2026-11-21 00:06.

The kernel signature repeats exactly. From 2026-11-21:

```
nvme nvme1: I/O tag 640 (e280) opcode 0x9 (Dataset Management) QID 6 timeout, aborting req_op:DISCARD(3) size:1620471808
nvme nvme1: I/O tag 641 (e281) opcode 0x9 (Dataset Management) QID 6 timeout, aborting req_op:DISCARD(3) size:190324736
nvme nvme1: Abort status: 0x0
nvme nvme1: I/O tag 640 (e280) opcode 0x9 (Dataset Management) QID 6 timeout, reset controller
nvme 0000:07:00.0: not ready 1023ms after FLR; waiting
nvme 0000:07:00.0: not ready 65535ms after FLR; giving up
nvme nvme1: Disabling device after reset failure: -25
XFS (nvme1n1p1): metadata I/O error in "xfs_btree_read_buf_block+0xaa/0x110 [xfs]" at daddr 0x2baa1810 len 8 error 5
XFS (nvme1n1p1): Block device removal (0x20) detected at fs_bdev_mark_dead+0xd9/0x180.  Shutting down filesystem.
```

The drive reads healthy at the same time. Measured 2026-11-28: SMART overall
PASSED, Media and Data Integrity Errors 0, Error Log Entries 0, Available Spare
100%, Percentage Used 0, composite 46 C, 5114 power on hours, 4.58 TB written,
60 unsafe shutdowns. The same firmware reports warning thresholds at 140/150 C
and 0% wear after five crashes, so its health counters carry little weight.

## Root cause

`Dataset Management` (opcode 0x9) is the command that carries TRIM: the host
declares LBA ranges free and the firmware updates its logical to physical map
and queues the freed NAND blocks for erase. One command here covered 1.6 GB.

The controller stops completing these commands without rejecting them. `Abort
status: 0x0` means the abort was not honored, the NVMe error log stays empty,
and neither a controller reset nor a PCIe function level reset brings the
device back. The kernel waits 65535 ms for it to become ready, then disables it.
XFS is told the block device is dead through `fs_bdev_mark_dead` and shuts the
filesystem down instead of writing into a dead disk.

TRIM is the trigger, not load in general: the drive serves reads and writes
normally (Steam ran a library from it on 2026-11-26), and only DSM commands
hang. FLR is implemented by the same firmware, so a wedged controller needs a
full power cycle, not a soft reboot, before it enumerates again.

## Fix

The workaround is a udev rule in `hosts/configuration.nix`, inside the existing
`services.udev.extraRules` block:

```
ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="nvme[0-9]n[0-9]", ATTRS{model}=="Netac NVMe SSD 2TB*", ATTR{queue/discard_max_bytes}="4194304"
```

The block layer splits every discard into pieces no larger than
`discard_max_bytes`, so the controller never receives the multi-gigabyte DSM
that wedges it. TRIM stays on, which matters for a drive without DRAM: the
controller keeps learning which blocks are free. See the 2026-09-22 incident in
`docs/nvme.md` for what happens when a DRAM-less controller loses that
information.

Do not zero `discard_max_bytes` on a running device as a shortcut.
`queue_max_discard_bytes_store` returns `EINVAL` for every later write once
discard is disabled (`blk_queue_discard()` is false), and neither
`rescan_controller` nor `reset_controller` brings the limit back. Re-enabling it
takes a reboot.

## Verification

After boot:

```
cat /sys/block/nvme*n1/queue/discard_max_bytes
```

The Netac prints `4194304`, the Kingston keeps its own larger value. The order
of the two lines follows the current device naming.

Measured 2026-11-28 after the reboot: four full `fstrim -v /mnt/ssd2tb` runs at
22:35 and 22:36, each discarding 1.08 TiB of free space in 15 to 17 seconds.
`/proc/diskstats` for the last run showed `discards_completed` +284,688 and
`sectors_discarded` +2,321,726,236, which is 4.0 MiB per command. The kernel log
for that boot contains no `Dataset Management timeout`, no `FLR` and no
`Disabling device`.

To re-check a run:

```
fstrim -v /mnt/ssd2tb
dev=$(basename "$(readlink -f /dev/disk/by-id/nvme-Netac_NVMe_SSD_2TB_RN202408202T336555)")
awk -v d="$dev" '$3 == d {print $15, $17}' /proc/diskstats
```

## Remaining risk

The defect is in the drive firmware and the cap only avoids the input that
triggers it. The original fault appeared after weeks of clean daily trims, so a
single successful boot proves nothing long term.

Watch for a return:

```
journalctl -k -b | grep 'Dataset Management timeout'
```

If it comes back, switch the rule to `ATTR{queue/discard_max_bytes}="0"` and
rebuild. That takes TRIM off this drive permanently and costs some write
throughput as the map ages. Either way, plan a replacement: a controller that
cannot be recovered by FLR is not worth keeping data on. Anything unique on
`/mnt/ssd2tb` needs a second copy; the syncthing folder already has one.

Alternatives that were ruled out:

- Firmware update. Netac ships no Linux updater, the PCI vendor ID is
  unregistered and no public image exists for `3.S.J.CU`.
- Leaving discard disabled from the start. It removes the trigger but throws
  away the free-block hints the controller depends on.
- Unbinding the PCIe device and rebinding it to reset the queue limits. The
  filesystem stays mounted across the unbind, so it would take the same I/O
  errors as a crash. A reboot is cheaper and cleaner.
