{ ... }:

{
  boot.tmp.useTmpfs = true;

  fileSystems."/nix/var/nix/builds" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "size=24G"
      "mode=0755"
      "nosuid"
      "nodev"
    ];
  };

  systemd.services.nix-daemon.unitConfig.RequiresMountsFor = "/nix/var/nix/builds";
}
