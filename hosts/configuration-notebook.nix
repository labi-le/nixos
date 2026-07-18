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
    ./../modules/battery.nix
    ./../modules/hibernation.nix
    ./../modules/adb.nix
    ./../modules/bluetooth.nix
    ./../modules/syncthing/notebook.nix
    ./../modules/steam.nix
    ./../modules/work-mount.nix
    ./../modules/fingerprint-elan.nix
  ];


  services.belphegor.enable = true;

  hardware = {
    graphics.enable = true;
  };

  system.stateVersion = "25.05";

  networking.networkmanager.wifi.powersave = false;
  systemd.services.NetworkManager-wait-online.enable = false;

  packages = {
    desktop = true;
  };

  ide = {
    goland.enable = true;
    # phpstorm.enable = true;
    # pycharm.enable = true;
  };

  monitors = {
    "eDP-1" = {
      mode = "1920x1080@144Hz";
      geometry = "0 0";
      position = "center";
    };
  };

}
