{ pkgs, ... }:

let
  device = "/dev/disk/by-uuid/b631c90c-690f-4cf0-9775-56c53f69f5b5";
in
{
  fileSystems."/drive" = {
    device = device;
    fsType = "ext4";
    options = [
      "noatime"
      "nofail"
    ];
  };

  # systemd.services."set-readahead-drive" = {
  #   description = "Set readahead for /dev/sda";
  #   wantedBy = [ "local-fs.target" ];
  #   serviceConfig.Type = "oneshot";
  #   serviceConfig.ExecStart = "${pkgs.util-linux}/bin/blockdev --setra 1024 ${device}";
  # };

  services.nfs = {
    server = {
      enable = true;
      exports = ''
        /drive 192.168.1.0/24(rw,sync,no_subtree_check,insecure)
      '';
      nproc = 16;
    };
    settings = {
      nfsd = {
        udp = false;
        vers3 = false;
        vers4 = true;
      };
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ 2049 ];
  };

  # boot.kernelPatches = [
  #   {
  #     name = "disable-nfs-readplus";
  #     patch = null;
  #     extraConfig = ''
  #       NFS_V4_2_READ_PLUS n
  #     '';
  #   }
  # ];
}
