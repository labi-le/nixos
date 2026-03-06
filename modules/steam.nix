{ pkgs, lib, ... }:
{
  programs.steam = {
    protontricks.enable = true;
    enable = true;
    package =
      with pkgs;
      steam.override {
        extraPkgs = pkgs: [
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
      };

    extraCompatPackages = [ pkgs.steamtinkerlaunch ];
  };

  environment.systemPackages = with pkgs; [
    steamtinkerlaunch
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
