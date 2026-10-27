{ lib, config, pkgs, ... }:

with lib;

let
  cfg = config.zfs;

  mirrorReadBias = pkgs.writeShellScript "zfs-mirror-read-bias" ''
    set -euo pipefail

    params=/sys/module/zfs/parameters

    ${pkgs.kmod}/bin/modprobe zfs

    printf '%s\n' ${toString cfg.hddReadPenalty} > "$params/zfs_vdev_mirror_rotating_inc"
    printf '%s\n' ${toString cfg.hddReadPenalty} > "$params/zfs_vdev_mirror_rotating_seek_inc"
  '';
in
{
  options.zfs = {
    enable = mkEnableOption "ZFS support on this host";

    hostId = mkOption {
      type = types.strMatching "[0-9a-f]{8}";
      description = "The 32-bit host id ZFS stamps into pool labels, as the first 8 hex characters of this host's /etc/machine-id. It must never change once a pool exists on this host, or the pool will refuse to import.";
    };

    autoScrub = mkOption {
      type = types.bool;
      default = false;
      description = "Enable periodic scrubbing of ZFS pools. Defaults off because it is a deliberate per-host opt-in: a monthly full-pool read is heavy I/O whose cost depends on pool size and member disk types (an SMR HDD scrubs far slower than an SSD), so a new ZFS host should choose its own schedule rather than inherit one silently. Hosts with a pool set this to true explicitly.";
    };

    scrubCalendar = mkOption {
      type = types.str;
      default = "*-*-01 02:30:00";
      description = "systemd.time(7) calendar expression passed to services.zfs.autoScrub.interval. Defaults to the 1st of each month at 02:30 local time, chosen to keep a scrub off an SMR mirror member entirely inside a night window; see docs/zfs-pool.md for why the randomized delay upstream normally adds to this had to be zeroed out as well.";
    };

    trim = mkOption {
      type = types.bool;
      default = true;
      description = "Enable periodic TRIM on all ZFS pools.";
    };

    hddReadPenalty = mkOption {
      type = types.ints.unsigned;
      default = 0;
      description = "Extra load units added to every rotating member of a mirror when ZFS picks which member serves a read. ZFS compares queue length plus this penalty and reads from the member with the lowest value, so a value above the SSD's queue depth (32 for SATA NCQ) keeps reads off a slow spinning mirror half, leaving it to absorb writes only. Zero keeps upstream behavior: the stock rotating_inc is 0, which makes sequential reads tie and split roughly evenly between the halves. See docs/zfs-pool.md.";
    };
  };

  config = mkIf cfg.enable {
    boot.supportedFilesystems = [ "zfs" ];
    networking.hostId = cfg.hostId;
    services.zfs.autoScrub.enable = cfg.autoScrub;
    services.zfs.autoScrub.interval = cfg.scrubCalendar;
    services.zfs.autoScrub.randomizedDelaySec = "0";
    services.zfs.trim.enable = cfg.trim;
    boot.zfs.forceImportRoot = false;

    boot.extraModprobeConfig = mkIf (cfg.hddReadPenalty > 0) ''
      options zfs zfs_vdev_mirror_rotating_inc=${toString cfg.hddReadPenalty} zfs_vdev_mirror_rotating_seek_inc=${toString cfg.hddReadPenalty}
    '';

    systemd.services.zfs-mirror-read-bias = mkIf (cfg.hddReadPenalty > 0) {
      description = "Bias ZFS mirror reads toward non-rotating members";
      wantedBy = [ "multi-user.target" ];
      after = [ "zfs-mount.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${mirrorReadBias}";
      };
    };
  };
}
