{ ... }:

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
    ./../modules/nvidia
  ];

  hardware = {
    graphics.enable = true;
  };

  system.stateVersion = "24.11";

  packages = {
    desktop = true;
  };

  monitors = {
    "eDP-1" = {
      mode = "1920x1080@144Hz";
      geometry = "0 0";
      position = "center";
    };
  };

  enablePrime = true;
  primeBusIds = {
    intel = "PCI:0:2:0";
    nvidia = "PCI:1:0:0";
  };
}
