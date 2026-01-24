{ pkgs, config, ... }:

{
  imports = [
    ./../modules/base.nix
    ./../modules/sound.nix
    ./../modules/greeter.nix
    ./../modules/wayland.nix
    ./../modules/nfs.nix
    ./../modules/thunar.nix
    ./../modules/kernel-zen.nix
    ./../modules/thunderbolt.nix
    # ./../modules/radeon.nix
    ./../modules/battery.nix
    ./../modules/hibernation.nix
    ./../modules/adb.nix
    ./../modules/bluetooth.nix
    ./../modules/syncthing/notebook.nix
  ];

  services.xserver.xkb = {
    layout = "us";
  };

  services.belphegor.enable = true;

  hardware = {
    graphics.enable = true;
  };

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  audio = {
    enable = true;
  };

  system.stateVersion = "25.05";

  networking.networkmanager.wifi.powersave = false;

  network.injectHosts = true;
  packages = {
    desktop = true;
  };

  ide = {
    goland.enable = true;
    # phpstorm.enable = true;
    pycharm = {
      enable = true;
    };
    rustrover = {
      enable = true;
      extraPackages = with pkgs; [
        libarchive
      ];
    };
  };

  hotkeys = {
    common = "Mod4";
    additional = "Mod1";
  };

  monitors = {
    "eDP-1" = {
      mode = "1920x1080@144Hz";
      geometry = "0 0";
      position = "center";
    };
  };
}
