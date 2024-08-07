{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.packages;
  desktopPackages = import ./packages-desktop.nix { inherit pkgs; };
  serverPackages = import ./packages-server.nix { inherit pkgs; };
in
{
  options.packages = {
    forServer = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc "Enable server-specific packages.";
    };

    forDesktop = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc "Enable desktop-specific packages.";
    };
  };

  config = {
    environment.systemPackages = with pkgs; [
      wget
      fastfetch
      gnumake
      lsof
      unzip
      jq
      openssl
      dig
      alacritty
      ranger
      btop
      git
      gparted
      psmisc # killall
      ncurses
      sshfs
      inetutils
    ] ++ optionals cfg.forDesktop desktopPackages
    ++ optionals cfg.forServer serverPackages;

    fonts.packages = with pkgs; optionals cfg.forDesktop [
      dejavu_fonts
      jetbrains-mono
      font-awesome
      noto-fonts
      noto-fonts-emoji
    ];
  };
}

