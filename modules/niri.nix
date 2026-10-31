{ config, lib, pkgs, ... }:

{
  programs.niri.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = lib.mkForce (with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-wlr
      xdg-desktop-portal-gtk
      gnome-keyring
    ]);
    config.niri.default = lib.mkDefault "gnome";
  };
}
