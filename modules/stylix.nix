{ pkgs, ... }:

{
  stylix = {
    enable = true;
    image = ../assets/wallpaper.jpg;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/dracula.yaml";
    polarity = "dark";

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
      sansSerif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Sans";
      };
      serif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Serif";
      };
    };

    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
    };

    icons = {
      enable = true;
      package = pkgs.dracula-icon-theme;
      dark = "Dracula";
      light = "Dracula";
    };

    opacity = {
      terminal = 0.5;
      desktop = 0.5;
    };
  };
}
