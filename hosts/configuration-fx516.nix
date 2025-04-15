{ ... }:

{
  imports = [
    ./modules/base.nix
    ./modules/sound.nix
    ./modules/greeter.nix
    ./modules/wayland.nix
    ./modules/sshfs.nix
    ./modules/thunar.nix
    ./modules/kernel-zen.nix
    ./modules/thunderbolt.nix
    ./modules/nvidia
  ];

  services.xserver.xkb = {
    layout = "us";
  };

  hardware = {
    graphics.enable = true;
  };

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  services.openssh.enable = true;

  system.stateVersion = "24.11";

  nix.gc.automatic = true;
  nix.gc.dates = "daily";

  network.injectHosts = true;
  packages = {
    desktop = true;
    dev = true;
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

  enablePrime = true;
  audio = {
    enable = true;
  };
}
