{ ... }:

{
  imports =
    [
      ./modules
      ./modules/home-drive.nix
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
  programs.dconf.enable = true;

  system.stateVersion = "24.11";

  nix.gc.automatic = true;
  nix.gc.dates = "daily";

  network.injectHosts = true;
  packages.forDesktop = true;

  networking.interfaces.enp37s0.wakeOnLan.enable = true;

  nix.settings = {
    substituters = [ "https://cache.nixos.org/" "https://cosmic.cachix.org/" ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
    ];
    auto-optimise-store = true;
  };
}
