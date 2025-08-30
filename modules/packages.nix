{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.packages;
  desktopPackages = import ./packages-desktop.nix { inherit pkgs; };
  serverPackages = import ./packages-server.nix { inherit pkgs; };
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

  };

  config = {
    environment.systemPackages =
      with pkgs;
      [
        wget
        gnumake
        lsof
        unzip
        jq
        openssl
        yazi

        dig
        nmap
        tcpdump
        mtr
        inetutils
        iperf3

        alacritty
        imv
        (btop.override {
          rocmSupport = true;
        })
        glances
        git
        lazygit

        gparted
        f2fs-tools

        psmisc # killall
        ncurses
        sshfs

        yt-dlp
        aria2

        gdu

        nix-tree
        nix-prefetch-git
        tree

        deal
        wireshark
        python3
        ffmpeg

      ]
      ++ optionals cfg.desktop desktopPackages
      ++ optionals cfg.server serverPackages;

    fonts = {
      enableDefaultPackages = true;
      packages =
        with pkgs;
        optionals cfg.desktop [
          nerd-fonts.dejavu-sans-mono
        ];
    };
  };

}
