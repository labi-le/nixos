{ ... }:

{
  imports = [
    ./../modules/base.nix
    ./../modules/sound.nix
    ./../modules/greeter.nix
    ./../modules/wayland.nix
    ./../modules/nfs.nix
    ./../modules/thunar.nix
    ./../modules/kernel.nix
    ./../modules/thunderbolt.nix
    # ./../modules/radeon.nix
    ./../modules/battery.nix
    ./../modules/adb.nix
    ./../modules/bluetooth.nix
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

  audio = {
    enable = true;
  };

  system.stateVersion = "25.05";

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

}
