{ pkgs, ... }:
{
  programs.steam = {
    enable = true;

    package = with pkgs; steam.override {
      extraPkgs = pkgs: [
        jq
        cabextract
        wget
        jdk21

        ftgl # font
      ];
    };
  };

  programs.gamemode.enable = true;

  environment.systemPackages = with pkgs; [
    # nix-gaming.faf-client
  ];
}
