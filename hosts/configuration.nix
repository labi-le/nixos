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
    ./../modules/kernel-zen.nix
    ./../modules/radeon.nix
    # ./../modules/vm.nix
    ./../modules/adb.nix
    ./../modules/vial.nix
    ./../modules/firefox.nix
    ./../modules/gamepad.nix
    ./../modules/syncthing/pc.nix
    ./../modules/k3s.nix
  ];

  services.xserver.xkb = {
    layout = "us";
  };

  services.belphegor.enable = true;

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
    rustrover.enable = true;
    pycharm.enable = true;
  };

  packages.desktop = true;

  networking.interfaces.eno1.wakeOnLan.enable = true;
  hotkeys = {
    common = "Mod1";
    additional = "Mod4";
  };
  monitors = {
    "DP-3" = {
      mode = "2560x1440@179.999Hz";
      geometry = "1920 0";
      position = "center";
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
