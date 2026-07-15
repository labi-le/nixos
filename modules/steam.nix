{ pkgs, lib, config, ... }:
let
  cfg = config.steamGamescope;
in
{
  options.steamGamescope = {
    width = lib.mkOption {
      type = lib.types.int;
      default = 1920;
      description = "gamescope output width";
    };
    height = lib.mkOption {
      type = lib.types.int;
      default = 1080;
      description = "gamescope output height";
    };
    refresh = lib.mkOption {
      type = lib.types.int;
      default = 144;
      description = "gamescope refresh rate (Hz)";
    };
  };

  config = {
    # nix-ld is enabled system-wide via modules/nix-ld.nix (imported by base.nix).
    programs.steam = {
      enable = true;
      package =
        with pkgs;
        steam.override {
          extraPkgs =
            pkgs: with pkgs; [
              jq
              cabextract
              wget
              git
              bubblewrap
              pkgsi686Linux.libpulseaudio
              pkgsi686Linux.freetype
              pkgsi686Linux.libxcursor
              pkgsi686Linux.libxcomposite
              pkgsi686Linux.libxi
              pkgsi686Linux.libxrandr
            ];
          extraProfile = ''
            export LD_AUDIT="${sls-steam}/library-inject.so:${sls-steam}/SLSsteam.so"
          '';
        };

      extraCompatPackages = [ pkgs.steamtinkerlaunch ];
    };

    home-manager.users.${config.mySystem.user.name} = {
      xdg.desktopEntries.steam = {
        name = "Steam";
        genericName = "Game Store";
        comment = "Application for managing and playing games on Steam";
        exec = "${pkgs.steam}/bin/steam -no-big-picture %U";
        icon = "steam";
        terminal = false;
        categories = [
          "Network"
          "FileTransfer"
          "Game"
        ];
        mimeType = [
          "x-scheme-handler/steam"
          "x-scheme-handler/steamlink"
        ];
      };
    };

    environment.systemPackages = with pkgs; [
      steamtinkerlaunch
      sls-steam
      sls-steam-wrapped
      lutris
      winetricks
      wineWow64Packages.stable
      mangohud
    ];

    programs.gamemode.enable = true;
    programs.gamescope = {
      enable = true;
      args = [
        "-w ${toString cfg.width}"
        "-h ${toString cfg.height}"
        "-r ${toString cfg.refresh}"
        "-f"
        "--rt"
        "--immediate-flips"
        "--adaptive-sync"
      ];
    };
  };
}
