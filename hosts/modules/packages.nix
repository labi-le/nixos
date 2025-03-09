{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.packages;
  desktopPackages = import ./packages-desktop.nix { inherit pkgs; };
  serverPackages = import ./packages-server.nix { inherit pkgs; };
  devPackages = import ./packages-dev.nix { inherit pkgs; };
in
{
  options.packages = {
    server = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc "Enable server-specific packages.";
    };

    desktop = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc "Enable desktop-specific packages.";
    };

    dev = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc "Enable dev-specific packages.";
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
      ranger

      dig
      nmap
      tcpdump
      mtr
      inetutils
      iperf3

      alacritty
      imv
      btop
      git
      lazygit

      gparted
      f2fs-tools

      psmisc # killall
      ncurses
      sshfs

      yt-dlp

      gdu

      nix-tree
      nix-prefetch-git
    ] ++ optionals cfg.desktop desktopPackages
    ++ optionals cfg.server serverPackages
    ++ optionals cfg.dev devPackages;

    fonts = {
      enableDefaultPackages = true;
      packages = with pkgs; optionals cfg.desktop [
        nerd-fonts.dejavu-sans-mono
      ];
      # fontconfig = {
      #   defaultFonts = {
      #     monospace = [ "DejaVu Sans Mono" ];
      #   };
      #
      # };
    };
  };

}

