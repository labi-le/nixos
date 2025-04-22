{
  fileSystems."/drive" = {
    device = "/dev/disk/by-uuid/b631c90c-690f-4cf0-9775-56c53f69f5b5";
    fsType = "ext4";
    options = [ "noatime" "nofail" ];
  };

  services.nfs.server = {
    enable = true;
    exports = ''
      /drive/
      192.168.1.0/24(rw,sync,no_subtree_check)
    '';
  };
  networking.firewall = {
    allowedTCPPorts =
      [ 2049 ];
    allowedUDPPorts = [ 2049 ];
  };
}
