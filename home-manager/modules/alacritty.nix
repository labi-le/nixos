{ pkgs, ... } :

{
  programs.alacritty.enable = true;
  programs.alacritty.settings = {
    font.size = 17;
    window.opacity = 0.4;
  };
}

