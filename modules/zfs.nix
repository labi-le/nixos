{ lib, config, ... }:

with lib;

let
  cfg = config.zfs;
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
      description = "Enable periodic scrubbing of ZFS pools. Off until a pool exists: with none, zfs-scrub.service runs zpool scrub -w with an empty pool list and fails on every trigger.";
    };

    trim = mkOption {
      type = types.bool;
      default = true;
      description = "Enable periodic TRIM on all ZFS pools.";
    };
  };

  config = mkIf cfg.enable {
    boot.supportedFilesystems = [ "zfs" ];
    networking.hostId = cfg.hostId;
    services.zfs.autoScrub.enable = cfg.autoScrub;
    services.zfs.trim.enable = cfg.trim;
    boot.zfs.forceImportRoot = false;
  };
}
