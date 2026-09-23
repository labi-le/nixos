{ ... }:

{
  boot.zfs.extraPools = [ "data" ];

  fileSystems."/torrents" = {
    device = "/dev/disk/by-uuid/d4cd9ea9-f656-438b-bd3f-e7bbbbd9e373";
    fsType = "ext4";
    options = [
      "x-systemd.device-timeout=30s"
      "x-systemd.mount-timeout=5min"
      "nofail"
    ];
  };

  fileSystems."/drive/torrents" = {
    device = "/torrents/torrents";
    fsType = "none";
    options = [
      "bind"
      "nofail"
      "x-systemd.requires-mounts-for=/torrents"
      "x-systemd.requires=zfs-mount.service"
    ];
  };

  services.nfs = {
    server = {
      enable = true;
      exports = ''
        /drive 192.168.1.0/24(rw,async,no_subtree_check,insecure)
        /drive/code 192.168.1.0/24(rw,async,no_subtree_check,insecure)
        /drive/sync 192.168.1.0/24(rw,async,no_subtree_check,insecure)
        /drive/state 192.168.1.0/24(rw,async,no_subtree_check,insecure)
        /drive/tmp 192.168.1.0/24(rw,async,no_subtree_check,insecure)
        /drive/torrents 192.168.1.0/24(rw,async,no_subtree_check,insecure)
      '';
      nproc = 16;
    };
    settings = {
      nfsd = {
        udp = false;
        vers3 = true;
        vers4 = true;
      };
      mountd.port = 20048;
    };
  };

  networking.firewall = {
    allowedTCPPorts = [
      2049
      111
      20048
    ];
    allowedUDPPorts = [
      111
      20048
    ];
  };

}
