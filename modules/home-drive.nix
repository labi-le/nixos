{
  fileSystems."/media/storage" = {
    device = "/dev/disk/by-uuid/b5eb331a-08e3-4942-ac86-25974cf29e10";
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
