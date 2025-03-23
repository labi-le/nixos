{ ... }:

{
  imports = [
    ./modules/base.nix
    ./modules/nginx.nix
    ./modules/drive.nix
    ./modules/kernel-zen.nix
    ./modules/grafana.nix
  ];

  # Configure keymap in X11
  services.xserver.xkb = { layout = "us"; };

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  hardware.graphics.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = { enable = true; };

  system.stateVersion = "24.11";

  nix.settings.auto-optimise-store = true;
  nix.gc.automatic = true;
  nix.gc.dates = "daily";

  packages = { server = true; };
}

