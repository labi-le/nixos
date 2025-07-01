{ pkgs, ... }:

{
  fileSystems."/drive" = {
    device = "/dev/disk/by-uuid/b631c90c-690f-4cf0-9775-56c53f69f5b5";
    fsType = "ext4";
    options = [
      "noatime"
      "nofail"
    ];
  };

  systemd.services."set-readahead-drive" = {
    description = "Set readahead for /dev/sda";
    wantedBy = [ "local-fs.target" ];
    serviceConfig.Type = "oneshot";
    serviceConfig.ExecStart = "${pkgs.util-linux}/bin/blockdev --setra 1024 /dev/sda";
  };

  services.nfs.server = {
    enable = true;
    exports = ''
      /drive/
      192.168.1.0/24(rw,sync,no_subtree_check,root_squash)
    '';
    nproc = 16;

  };
  networking.firewall = {
    allowedTCPPorts = [ 2049 ];
  };
}
