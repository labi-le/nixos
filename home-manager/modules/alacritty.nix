{ pkgs, ... }:

{
  programs.alacritty = {
    enable = true;
    settings = { };
  };
  xdg.terminal-exec = {
    settings = {
      default = [ "alacritty.desktop" ];
    };
  };

}
