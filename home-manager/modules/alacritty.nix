{ pkgs, ... }:

{
  programs.alacritty = {
    enable = true;
    package = pkgs.alacritty;
    settings = {
      font.size = 17.0;
      window.opacity = 0.1;
    };

  };

}

