{ ... }:

{
  imports =
    [
      ./modules
    ];


  services.xserver.xkb = {
    layout = "us";
  };

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  hardware.graphics.enable = true;

  programs.gnupg.agent = {
    enable = true;
  };

  system.stateVersion = "24.11";

  nix.settings.auto-optimise-store = true;
  nix.gc.automatic = true;
  nix.gc.dates = "daily";

  network.injectHosts = true;
  packages.forDesktop = true;

  networking.interfaces.enp37s0.wakeOnLan.enable = true;
  musnix.enable = true;
}
