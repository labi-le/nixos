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
          # Use the libraries from the SLSsteam package directly.
          # ld.so will use these for 64-bit processes (like RE4).
          LD_AUDIT = "${inputs.sls-steam.packages.${pkgs.stdenv.hostPlatform.system}.default}/library-inject.so:${inputs.sls-steam.packages.${pkgs.stdenv.hostPlatform.system}.default}/SLSsteam.so";
        };
      };

    extraCompatPackages = [ pkgs.steamtinkerlaunch ];
  };

  environment.systemPackages = with pkgs; [
    steamtinkerlaunch
    inputs.sls-steam.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.sls-steam.packages.${pkgs.stdenv.hostPlatform.system}.wrapped
  ];

  # Add configuration for SLSsteam
  home-manager.users.labile = {
    xdg.configFile."SLSsteam/config.yaml".text = ''
      # SLSsteam configuration
      SafeMode: no
      WarnHashMissmatch: no
      DisableFamilyShareLock: yes
      PlayNotOwnedGames: yes
      UseWhitelist: no
      AppIds: []
      AdditionalApps: []
      DlcData: {}
      FakeAppIds: {}
      LogLevel: 2
      LogToFile: no
      API: yes
    '';
  };

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
