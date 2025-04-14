{ pkgs, ... }:

{
  programs.alacritty = {
    enable = true;
    package = pkgs.alacritty;
    settings = {
      font.size = 17.0;
      font.normal.family = "DejaVu Sans Mono";
      window.opacity = 0.7;
    };

  };

}
