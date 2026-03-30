{ pkgs, lib, ... }:
{
  programs.nix-ld.enable = true;
  programs.steam = {
    protontricks.enable = true;
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

  home-manager.users.labile = {
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
    accela
    lutris
  ];

  programs.gamemode.enable = true;
  programs.gamescope = {
    enable = true;
    args = [
      "-w 2560"
      "-h 1440"
      "-r 180"
      "-f"
      "--rt"
      "--immediate-flips"
      "--adaptive-sync"
    ];
  };

}
