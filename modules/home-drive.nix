{
  fileSystems."/media/storage" = {
    device = "/dev/disk/by-uuid/fbd1306f-612b-4032-bd8c-445087dd7782";
    fsType = "f2fs";
    options = [
      "defaults"
      "nofail"
      "x-systemd.automount"
      "rw"
      "noatime"
      "nodiratime"
      "async"
    ];
  };
}
