{
  fileSystems."/home/labile/external_storage" = {
    device = "/dev/disk/by-uuid/7F99-F331";
    fsType = "exfat";
    options = [
      "defaults"
      "nofail"
      "x-systemd.automount"
      "uid=1000"
      "gid=100"
      "noatime"
      "nodiratime"
      "async"
      "utf8"
    ];
  };
}
