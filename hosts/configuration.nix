{ pkgs, ... }:

let
  openrgbApplyOff = pkgs.writeShellScript "openrgb-apply-off" ''
    set -u
    port=6742
    profile=/home/labile/.config/OpenRGB/off.orp
    orgb=${pkgs.openrgb}/bin/openrgb

    prev=""
    stable=0
    for ((i = 0; i < 40; i++)); do
      count=$("$orgb" --client "127.0.0.1:$port" --nodetect --list-devices 2>/dev/null | grep -cE '^[0-9]+: ')
      if [ "''${count:-0}" -gt 0 ] && [ "$count" = "$prev" ]; then
        stable=$((stable + 1))
        [ "$stable" -ge 2 ] && break
      else
        stable=0
      fi
      prev="$count"
      sleep 1
    done

    exec "$orgb" --client "127.0.0.1:$port" --nodetect --profile "$profile"
  '';
in
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

  services.xserver.xkb = {
    layout = "us";
  };

  services.belphegor.enable = true;
  services.hardware.openrgb.enable = true;
  systemd.services.openrgb-apply-off = {
    description = "Apply OpenRGB 'off' profile once the SDK server is ready";
    after = [ "openrgb.service" ];
    requires = [ "openrgb.service" ];
    partOf = [ "openrgb.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.coreutils pkgs.gnugrep ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${openrgbApplyOff}";
    };
  };
  virtualisation.waydroid.enable = true;

  programs.gnupg.agent = {
    enable = true;
  };
  programs.dconf.enable = true;
  system.stateVersion = "24.11";

  network.injectHosts = true;
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
  hotkeys = {
    common = "Mod4";
    additional = "Mod1";
  };
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
    # "DP-3" = {
    #   mode = "--custom 2560x1440@83Hz";
    #   transform = "270";
    #   geometry = "4480 0";
    #   position = "right";
    # };
  };
  audio = {
    enable = true;
    lowLatency = true;
  };

}
