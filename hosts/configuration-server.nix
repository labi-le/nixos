{ config, inputs, lib, ... }:

{
  imports = [
    ./../modules/base.nix
    ./../modules/nginx.nix
    ./../modules/litellm.nix
    ./../modules/drive.nix
    ./../modules/kernel-cachyos.nix
    ./../modules/grafana.nix
    ./../modules/monitoring
    inputs.sub-preprocessor.nixosModules.monitoring
    inputs.tidal-syncer.nixosModules.default
    ./../modules/tidal-syncer.nix
    ./../modules/frp.nix
    ./../modules/syncthing/server.nix
    ./../modules/nvidia/gt210.nix
    ./../modules/vaultwarden.nix
    ./../modules/qbittorrent.nix
    ./../modules/awg
    ./../modules/network
    ./../modules/chromadb.nix
    ./../modules/harmonia.nix
  ];

  network = {
    enableFirewall = true;
  };

  age.secrets.ngate-env = {
    file = ../secrets/ngate-env.age;
    mode = "600";
    owner = "root";
  };

  age.secrets.litellm-env = {
    file = ../secrets/litellm-env.age;
    owner = "labile";
    group = "users";
    mode = "0400";
  };

  age.secrets.harmonia-key = {
    file = ../secrets/harmonia-key.age;
    mode = "0400";
  };

  nix.gc.automatic = lib.mkForce false;
  nix.settings.trusted-users = [ "labile" ];

  services.ngate-wrapped-vm = {
    enable = true;
    envFile = config.age.secrets.ngate-env.path;
    routes = "79.137.220.62 10.0.0.0/8 185.129.100.112/32 10.206.185.123/32 10.89.58.17/32";
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
  networking.interfaces.enp37s0.wakeOnLan.enable = true;
}
