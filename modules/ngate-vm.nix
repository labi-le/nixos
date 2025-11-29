{ lib
, pkgs
, config
, ...
}:

with lib;

let
  cfg = config.services.debian-sakura-vm;
  system = pkgs.stdenv.hostPlatform.system;
  flakeVm = builtins.getFlake cfg.flakePath;
in
{
  options.services.debian-sakura-vm = {
    enable = mkEnableOption "Debian Sakura VM service";

    flakePath = mkOption {
      type = types.path;
      description = "Path to the flake that exposes apps.<system>.default.program for the VM runner";
    };

    ports = mkOption {
      type = types.listOf types.port;
      default = [
        6080
        49157
      ];
      description = "TCP ports to open in the firewall for the VM";
    };

    bridges = mkOption {
      type = types.listOf types.str;
      default = [ "br0" ];
      description = "Bridge interfaces allowed in qemu bridge.conf";
    };

    stateDirectory = mkOption {
      type = types.str;
      default = "debian-sakura-vm";
      description = "systemd StateDirectory for the VM";
    };

    workingDirectory = mkOption {
      type = types.str;
      default = "/var/lib/debian-sakura-vm";
      description = "WorkingDirectory for the VM service";
    };

    user = mkOption {
      type = types.str;
      default = "root";
      description = "User for the VM service";
    };

    group = mkOption {
      type = types.str;
      default = "root";
      description = "Group for the VM service";
    };

    serviceName = mkOption {
      type = types.str;
      default = "debian-sakura-vm";
      description = "Name of the systemd service";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = cfg.ports;

    security.wrappers.qemu-bridge-helper = {
      source = "${pkgs.qemu}/libexec/qemu-bridge-helper";
      owner = "root";
      group = "root";
      setuid = true;
      permissions = "u+xs,g+x,o-x";
    };

    environment.etc."qemu/bridge.conf".text =
      concatStringsSep "\n" (map (name: "allow ${name}") cfg.bridges) + "\n";

    systemd.services."${cfg.serviceName}" = {
      description = "Debian Sakura VM from flake";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.workingDirectory;
        StateDirectory = cfg.stateDirectory;

        ExecStart = "${flakeVm.apps.${system}.default.program}";
        Restart = "on-failure";
      };
    };
  };
}
