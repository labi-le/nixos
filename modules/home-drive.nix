{ config, lib, ... }:
{
  options.homeDrive.device = lib.mkOption {
    type = lib.types.str;
    description = "Backing device for the /media/storage f2fs mount (set per-host).";
  };

  config.fileSystems."/media/storage" = {
    device = config.homeDrive.device;
    fsType = "f2fs";
    options = [
      "defaults"
      "nofail"
      "x-systemd.automount"
      "_netdev"
      "x-systemd.after=network-online.target"
      "x-systemd.requires=network-online.target"
      "rw"
      "noatime"
      "nodiratime"
      "async"
    ];
  };
}
