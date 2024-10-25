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
      nmap
      tcpdump
      mtr
      inetutils
      iperf3
      ipcalc

      alacritty
      ranger
      imv
      btop
      git
      gparted
      psmisc # killall
      ncurses
      sshfs
      fselect

      yt-dlp

      gdu

      pgcli
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

