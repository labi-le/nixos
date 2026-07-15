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
      description = "Enable server-specific packages.";
    };

    desktop = mkOption {
      type = types.bool;
      default = false;
      description = "Enable desktop-specific packages.";
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
        (glances.overridePythonAttrs (_: {
          doCheck = false;
        }))
        git
        lazygit

        (gparted.override {
          withAllTools = true;
        })

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
        agenix
        age
        screen

        pgcli

        generate-context
      ]
      ++ optionals cfg.desktop desktopPackages
      ++ optionals cfg.server serverPackages;

    programs.wl-paste-uploader = mkIf cfg.desktop {
      enable = true;
      ocr = true;
    };

    fonts = mkIf cfg.desktop {
      enableDefaultPackages = true;
      packages = with pkgs; [
        apple-fonts.sf-pro
        apple-fonts.sf-mono
        apple-fonts.sf-pro-nerd

      ];

      fontconfig = {
        defaultFonts = {
          sansSerif = [ "SF Pro Display" ];
          monospace = [ "SF Mono" ];
        };
      };
    };
  };

}
