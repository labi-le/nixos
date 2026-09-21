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
| `data` | `/drive` | inherited | zstd | — | root, otherwise empty |
| `data/code` | `/drive/code` | 128K | zstd | — | freqtrade container source/state; general-purpose default recordsize, benefits from zstd on source text |
| `data/sync` | `/drive/sync` | 1M | lz4 | — | large, mostly-sequential file transfers; 1M matches large sequential I/O, lz4 is cheap CPU for content that often isn't very compressible |
| `data/state` | `/drive/state` | 16K | lz4 | `logbias=latency` | small, latency-sensitive state (e.g. ChromaDB's SQLite-backed store, bind-mounted from `modules/chromadb.nix`); small recordsize limits read-modify-write amplification on small random writes, `logbias=latency` tells ZFS to route synchronous writes through the ZIL for lower latency instead of optimizing for throughput |
| `data/tmp` | `/drive/tmp` | 1M | lz4 | — | scratch space, large sequential I/O |

Measured compression ratios from `zfs get compressratio`: pool `data` 1.25x, `data/code` 1.22x (zstd), `data/state` 1.29x (lz4), `data/sync` 1.04x (lz4), `data/tmp` 2.66x (lz4). Only `data/code` runs zstd; the rest use lz4 because their content is already compressed or latency-sensitive. `data/sync` at 1.04x exemplifies why zstd would not pay for large sequential transfers: lz4's 1.04x is the minimal overhead of the algorithm itself.

## Performance characteristics that matter operationally

- **Asynchronous writes are cheap for the SMR half.** ZFS batches dirty data into transaction groups (txg, ~5 s by default) and flushes each txg as a large, mostly-sequential write. SMR drives are pathologically slow at small random writes but tolerate large sequential ones reasonably well, so ordinary buffered I/O on this pool does not expose the HDD's shingled-write penalty.
- **Every `fsync` waits on the HDD.** There is no separate log device (SLOG). Synchronous writes (`fsync`, `O_SYNC`, NFS `sync` exports, database commits) must be committed to the pool's own ZIL before returning, and with a mirror vdev that means waiting on the slower member — the SMR disk. A SLOG would remove this wait for small sync writes, but there is currently no free space on the system NVMe to carve one out without shrinking its ext4 partition offline; this is deferred, not solved.

## Torrents: deliberately single-copy, off the pool

`/backup/torrents` and `/backup/torrents_db` live on the separate 4 TB ext4 disk (`/backup`) and are bind-mounted to `/drive/torrents` and `/drive/torrents_db` (see `modules/drive.nix`) purely so qBittorrent's fastresume files — which embed absolute paths for existing torrents — keep working. The data itself is **not** on the `data` pool and has no second copy. This is intentional: torrent content is independently re-fetchable from swarms, so it doesn't need mirror redundancy or pool space, and keeping it off the pool avoids doubling the SMR write load with the highest-churn dataset on the host.

## Swap must never go on this pool

A ZFS zvol used as a swap device can deadlock the kernel: reclaiming memory under pressure can need to allocate memory inside the ZFS write path (ZIO, ABD) to service the swap-out I/O itself, and on some kernels that circular dependency wedges the whole system. This is a long-standing, still-open upstream issue: [openzfs/zfs#7734](https://github.com/openzfs/zfs/issues/7734). Swap on this host stays exactly where `modules/swap.nix` puts it — zram and a plain file on the root NVMe — never on a ZFS dataset or zvol.
