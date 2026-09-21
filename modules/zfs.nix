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
      description = "Enable periodic scrubbing of ZFS pools. Defaults off because it is a deliberate per-host opt-in: a monthly full-pool read is heavy I/O whose cost depends on pool size and member disk types (an SMR HDD scrubs far slower than an SSD), so a new ZFS host should choose its own schedule rather than inherit one silently. Hosts with a pool set this to true explicitly.";
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
