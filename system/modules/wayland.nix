{ pkgs, ... }:

{
  xdg.portal.enable = true;
  xdg.portal.extraPortals = with pkgs; [
    xdg-desktop-portal-wlr
    xdg-desktop-portal-gtk
  ];
  programs.xwayland.enable = true;
  xdg.portal.config.common.default = "*";

}
