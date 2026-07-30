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

  # The box can hard-hang with no logs at all (a too-deep Curve Optimizer did it
  # for five days in July 2026). The FCH timer reboots it after 60s instead of
  # waiting for the reset button; systemd stops feeding /dev/watchdog on any
  # hang, so this costs nothing while the machine is healthy.
  boot.kernelModules = [ "sp5100_tco" ];
  systemd.settings.Manager.RuntimeWatchdogSec = "60s";

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

  # fbcon sizes the text grid to the *smallest* connected output (here DP-2's
  # 1920x1080) while the shared framebuffer is the bounding box (2560x1440), so
  # the greeter painted only the top-left 1920x1080 of DP-1. Pinning DP-1's
  # console mode to 1920x1080 makes the console cover the whole scanout; the
  # monitor upscales it, and sway still picks 2560x1440@180 from EDID after
  # login. Console only -- KMS clients ignore this.
  boot.kernelParams = [ "video=DP-1:1920x1080" ];

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
