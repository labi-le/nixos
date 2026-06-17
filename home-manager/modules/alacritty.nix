{ pkgs, lib, ... }:

{
  programs.alacritty = {
    enable = true;
    settings = {
      font = {
        size = lib.mkForce 15;
      };
    };
  };
  xdg.terminal-exec = {
    settings = {
      default = [ "alacritty.desktop" ];
    };
  };

}
