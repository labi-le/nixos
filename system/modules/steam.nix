{ pkgs, ... }:
{
  programs.steam = {
    enable = true;

    package = with pkgs; steam.override {
      extraPkgs = pkgs: with pkgs; [
        jq
        cabextract
        wget
        jdk21
        ftgl
        freetype
        pkgsi686Linux.libpulseaudio
        gtk3
        openjfx
      ];
    };
  };

  hardware.graphics.enable32Bit = true;

  programs.gamemode.enable = true;

  # Java configuration
  programs.java = {
    enable = true;
    package = pkgs.jdk21;
  };

  # Environment variables for Java
  environment.variables = {
    JAVA_HOME = "${pkgs.jdk21}/lib/openjdk";
    INSTALL4J_JAVA_HOME = "${pkgs.jdk21}/lib/openjdk";
    PATH = [ "${pkgs.jdk21}/bin" ];
  };

  environment.systemPackages = with pkgs; [
    #nix-gaming.faf-client
    jdk21
  ];
}
