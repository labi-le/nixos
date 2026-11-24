{
  config,
  inputs,
  lib,
  pkgs,
  user,
  ...
}:

let
  userCfg = config.users.users.${user.name};
  maksutDir = "${userCfg.home}/projects/maksut";
in
{
  imports = [
    ./../modules/base.nix
    ./../modules/nginx.nix
    ./../modules/litellm
    ./../modules/buer
    ./../modules/drive.nix
    ./../modules/kernel-server.nix
    ./../modules/zfs.nix
    ./../modules/grafana.nix
    ./../modules/monitoring
    inputs.sub-preprocessor.nixosModules.monitoring
    inputs.tidal-syncer.nixosModules.default
    ./../modules/tidal-syncer.nix
    ./../modules/music-assistant.nix
    ./../modules/home-assistant
    ./../modules/bifrons.nix
    ./../modules/frp.nix
    ./../modules/syncthing/server.nix
    ./../modules/vaultwarden.nix
    ./../modules/qbittorrent.nix
    ./../modules/awg
    ./../modules/network
    ./../modules/chromadb.nix
    ./../modules/swap.nix
    ./../modules/oom.nix
    ./../modules/tmpfs.nix
    ./../modules/harmonia.nix
    ./../modules/unbound.nix
    ./../modules/ifconfig.nix
    ./../modules/btop.nix
    ./../modules/maki
  ];

  services.btop.enable = true;

  network = {
    enableFirewall = true;
    lanInterface = "enp42s0";
    wakeOnLan = true;
    staticLan = true;
  };

  drive.hddDevice = "/dev/disk/by-uuid/d4cd9ea9-f656-438b-bd3f-e7bbbbd9e373";
  zfs = {
    enable = true;
    hostId = "204cf2f5";
    autoScrub = true;
    hddReadPenalty = 100;
  };

  swapDevices = lib.mkForce [ ];

  age.secrets.ngate-env = {
    file = ../secrets/ngate-env.age;
    mode = "600";
    owner = "root";
  };

  age.secrets.litellm-env = {
    file = ../secrets/litellm-env.age;
    owner = user.name;
    group = userCfg.group;
    mode = "0400";
  };

  age.secrets.harmonia-key = {
    file = ../secrets/harmonia-key.age;
    mode = "0400";
  };

  nix.gc = lib.mkForce {
    automatic = true;
    dates = "*-*-01,15 04:00:00";
    options = "";
    persistent = true;
    randomizedDelaySec = "1h";
  };
  nix.settings.trusted-users = [ user.name ];
  users.users.${user.name}.openssh.authorizedKeys.keys = [
    "command=\"nix-store --serve --write\",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIK4XUt2RWmKFHA+eKh4mP6k580R5pk/0IsuK/XRgSUx cache-push"
  ];

  services.ngate-wrapped-vm = {
    enable = true;
    envFile = config.age.secrets.ngate-env.path;
    routes = "79.137.220.62 10.0.0.0/8 185.129.100.112/32 10.206.185.123/32 10.89.58.17/32";
    workingDirectory = "/drive/state/ngate-wrapped-vm";
  };

  systemd.services.ngate-wrapped-vm = {
    startLimitIntervalSec = 0;
    serviceConfig.RestartSec = 5;
  };

  systemd.services.maksut-deploy-hook = {
    description = "Maksut GitHub deploy webhook";
    after = [
      "docker.service"
      "network-online.target"
    ];
    wants = [
      "docker.service"
      "network-online.target"
    ];
    path = [
      config.system.path
      pkgs.python3
      pkgs.git
    ];
    environment = {
      AUTO_DEPLOY_REPO = maksutDir;
      AUTO_DEPLOY_STATE_DIR = "${maksutDir}/self-improve";
      MAKSUT_HOOK_HOST = "127.0.0.1";
      MAKSUT_HOOK_PORT = "6551";
      MAKSUT_HOOK_PATH = "/webhook/maksut-deploy";
      MAKSUT_HOOK_SECRET_FILE = "${maksutDir}/.secrets/deploy-hook.secret";
    };
    serviceConfig = {
      User = user.name;
      Group = userCfg.group;
      WorkingDirectory = maksutDir;
      ExecStart = "${pkgs.python3}/bin/python3 ${maksutDir}/tools/deploy_hook.py";
      Restart = "on-failure";
      RestartSec = 5;
      NoNewPrivileges = true;
    };
    wantedBy = [ "multi-user.target" ];
  };

  systemd.services.maksut-self-improve = {
    description = "Maksut self-improvement orchestrator";
    after = [ "docker.service" ];
    wants = [ "docker.service" ];
    path = [
      config.system.path
      pkgs.python3
      pkgs.git
    ];
    environment = {
      SELF_IMPROVE_REPO = maksutDir;
      SELF_IMPROVE_DIR = "${maksutDir}/self-improve";
      SELF_IMPROVE_OMP = "/run/current-system/sw/bin/omp";
    };
    serviceConfig = {
      User = user.name;
      Group = userCfg.group;
      WorkingDirectory = maksutDir;
      EnvironmentFile = "${maksutDir}/.env";
      ExecStart = "${pkgs.python3}/bin/python3 ${maksutDir}/tools/self_improve_orchestrator.py";
      Restart = "on-failure";
      RestartSec = 10;
      NoNewPrivileges = true;
    };
    wantedBy = [ "multi-user.target" ];
  };

  boot.kernel.sysctl = {
    "vm.dirty_background_ratio" = 15;
    "vm.dirty_ratio" = 30;
    "vm.dirty_expire_centisecs" = 30 * (60 * 100); # 1m = 60*100;
    "vm.dirty_writeback_centisecs" = 30 * (60 * 100);
  };

  hardware.graphics.enable = true;

  system.stateVersion = "24.11";

  packages = {
    server = true;
  };

  services.logind.settings.Login.HandleLidSwitch = "ignore";
}
