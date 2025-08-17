{ ... }:

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
  ];

  services.xserver.xkb = {
    layout = "us";
  };

  programs.gnupg.agent = {
    enable = true;
  };
  programs.dconf.enable = true;
  programs.amnezia-vpn.enable = true;

  system.stateVersion = "24.11";

  network.injectHosts = true;
  networking.firewall.allowedTCPPorts = [ 9003 ];
  packages = {
    desktop = true;
    dev = true;
    ide = true;
  };

  networking.interfaces.enp37s0.wakeOnLan.enable = true;
  hotkeys = {
    common = "Mod1";
    additional = "Mod4";
  };
  monitors = {
    "DP-2" = {
      mode = "2560x1440@179.999Hz";
      geometry = "1920 0";
      position = "center";
    };
    "DP-1" = {
      mode = "1920x1080@165Hz";
      geometry = "0 0";
      position = "left";
    };
    "DP-3" = {
      mode = "--custom 2560x1440@83Hz";
      transform = "270";
      geometry = "4480 0";
      position = "right";
    };
  };
  audio = {
    enable = true;
    lowLatency = true;
  };
}
