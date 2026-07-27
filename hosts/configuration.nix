{ pkgs, ... }:

{
  imports = [
    ./../modules/home-drive.nix
    ./../modules/base.nix
    ./../modules/sound.nix
    ./../modules/greeter.nix
    ./../modules/uxplay.nix
    ./../modules/wayland.nix
    ./../modules/nfs.nix
    ./../modules/thunar.nix
    ./../modules/kernel-cachyos.nix
    ./../modules/radeon.nix
    # ./../modules/vm.nix
    ./../modules/adb.nix
    ./../modules/vial.nix
    ./../modules/firefox.nix
    ./../modules/gamepad.nix
    ./../modules/syncthing/pc.nix
    ./../modules/k3s.nix
    ./../modules/steam.nix
    ./../modules/esync.nix
    ./../modules/bluetooth.nix
    ./../modules/amd
    ./../modules/work-mount.nix
  ];

  networking.firewall = {
    allowedTCPPorts = [ 10808 ];
    allowedUDPPorts = [ 10808 ];
  };

  services.belphegor.enable = true;
  virtualisation.waydroid.enable = true;

  # GPU profile lives in the repo instead of being hand-placed in /etc. Raw
  # YAML rather than services.lact.settings: that option renders through
  # pkgs.formats.yaml, which quotes map keys, and lactd then dies on the fan
  # curve with `invalid type: string "40", expected i32`.
  environment.etc."lact/config.yaml".source = ./lact-pc.yaml;
  systemd.services.lactd.restartTriggers = [ ./lact-pc.yaml ];

  programs.dconf.enable = true;
  system.stateVersion = "24.11";

  ide = {
    goland.enable = true;
    phpstorm = {
      enable = true;
      extraVmOptions = ''
        -Xmx8192m
        -Xms2048m
      '';
    };
    # rustrover.enable = true;
    # pycharm.enable = true;
    rider.enable = true;
  };

  packages.desktop = true;

  networking.interfaces.eno1.wakeOnLan.enable = true;
  monitors = {
    "DP-1" = {
      mode = "2560x1440@179.999Hz";
      geometry = "1920 0";
      position = "right";
      primary = true;
    };
    "DP-2" = {
      mode = "1920x1080@165Hz";
      geometry = "0 0";
      position = "left";
    };
  };
  audio = {
    lowLatency = true;
  };

  steamGamescope = {
    width = 2560;
    height = 1440;
    refresh = 180;
  };

  homeDrive.device = "/dev/disk/by-uuid/fbd1306f-612b-4032-bd8c-445087dd7782";

}
