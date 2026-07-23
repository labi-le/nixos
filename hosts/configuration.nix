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
  services.hardware.openrgb.enable = true;
  systemd.services.openrgb.preStart = ''
    config=/var/lib/OpenRGB/OpenRGB.json
    if [ -f "$config" ]; then
      ${pkgs.jq}/bin/jq '.Detectors.detectors."Keychron Q6 Max" = false | del(.Detectors."Keychron Q6 Max")' "$config" > "$config.new" \
        && ${pkgs.coreutils}/bin/mv -f "$config.new" "$config"
    fi
  '';
  virtualisation.waydroid.enable = true;

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
