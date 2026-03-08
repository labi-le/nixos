{ pkgs, inputs, ... }:
{
  programs.nix-ld.enable = true;
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
        extraEnv = {
          LD_AUDIT = "${sls-steam}/library-inject.so:${sls-steam}/SLSsteam.so";
        };
      };

    extraCompatPackages = [ pkgs.steamtinkerlaunch ];
  };

  environment.systemPackages = with pkgs; [
    steamtinkerlaunch
    sls-steam
    sls-steam-wrapped
    accela
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
