{ pkgs, lib, ... }:
{
  programs.steam = {
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
  };

  programs.gamemode.enable = true;
  programs.gamescope = {
    enable = true;
    args = [
      "-W 2560"
      "-H 1440"
      "-r 144"
      "-f"
    ];
  };

}
