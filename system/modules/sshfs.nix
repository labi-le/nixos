{
  fileSystems."/drive" = {
    device = "labile@192.168.1.2:/drive";
    fsType = "sshfs";
    options = [
      "nodev"
      "noatime"
      "allow_other"
      "debug"
      "sshfs_debug"
    ];
  };
}
