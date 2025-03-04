{ ... }:

{
  imports =
    [
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
    ];


  services.xserver.xkb = {
    layout = "us";
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.rocmSupport = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  hardware.graphics.enable = true;

  programs.gnupg.agent = {
    enable = true;
  };
  programs.dconf.enable = true;

  system.stateVersion = "24.11";

  nix.gc.automatic = true;
  nix.gc.dates = "daily";

  network.injectHosts = true;
  packages = { desktop = true; dev = true; };

  networking.interfaces.enp37s0.wakeOnLan.enable = true;
}
