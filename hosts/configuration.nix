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

  nix.settings = {
    substituters = [ "https://cache.nixos.org/" "https://cosmic.cachix.org/" "https://cache.garnix.io" ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
    auto-optimise-store = true;
  };
}
