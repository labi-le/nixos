{ pkgs, lib, ... }:

{
  programs.alacritty = {
    enable = true;
    settings = {
      font = {
        size = lib.mkForce 17;
      };
    };
  };
  xdg.terminal-exec = {
    settings = {
      default = [ "alacritty.desktop" ];
    };
  };

}
