{ config, pkgs, ... }:

let
  flakeVm = builtins.getFlake "/home/labile/projects/ngate-wrapped/qcow2";
  system = pkgs.stdenv.hostPlatform.system;
in
{

  networking.firewall = {
    allowedTCPPorts = [
      6080
      49157
    ];
  };

  security.wrappers.qemu-bridge-helper = {
    source = "${pkgs.qemu}/libexec/qemu-bridge-helper";
    owner = "root";
    group = "root";
    setuid = true;
    permissions = "u+xs,g+x,o-x";
  };

  environment.etc."qemu/bridge.conf".text = ''
    allow br0
  '';
  systemd.services.debian-sakura-vm = {
    description = "Debian Sakura VM from flake";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "root";
      Group = "root";
      WorkingDirectory = "/var/lib/debian-sakura-vm";
      StateDirectory = "debian-sakura-vm";

      ExecStart = "${flakeVm.apps.${system}.default.program}";
      Restart = "on-failure";
    };
  };
}
