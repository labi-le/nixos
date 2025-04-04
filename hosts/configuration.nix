{ ... }:

{
  imports = [
    ./modules/home-drive.nix
    ./modules/base.nix
    ./modules/sound.nix
    ./modules/greeter.nix
    ./modules/uxplay.nix
    ./modules/wayland.nix
    ./modules/sshfs.nix
    ./modules/thunar.nix
    ./modules/kernel-cachyos.nix
    ./modules/spicetify.nix
    ./modules/thunderbolt.nix
    ./modules/radeon.nix
  ];

  builders = {
    enableRemoteBuilding = true;
    remoteBuilders = {
      mainServer = {
        host = "192.168.1.2";
        keyFile = "/home/labile/.ssh/nix-builder";
      };
    };
  };

  services.xserver.xkb = {
    layout = "us";
  };
  hardware.graphics.enable = true;

  programs.gnupg.agent = {
    enable = true;
  };
  programs.dconf.enable = true;

  system.stateVersion = "24.11";

  nix.gc.automatic = true;
  nix.gc.dates = "daily";

  network.injectHosts = true;
  packages = {
    desktop = true;
    dev = true;
    ide = true;
  };

  networking.interfaces.enp37s0.wakeOnLan.enable = true;

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
}
