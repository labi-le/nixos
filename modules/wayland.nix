{ config, lib, pkgs, ... }:

let
  wlrootsSession = !config.programs.niri.enable;
in
{
  xdg.portal.enable = true;
  xdg.portal.extraPortals = lib.optionals wlrootsSession [ pkgs.xdg-desktop-portal-wlr ];
  programs.xwayland.enable = true;
  xdg.portal.config.common.default = "*";

  systemd.user.services.xdg-desktop-portal-wlr = lib.mkIf wlrootsSession {
    overrideStrategy = "asDropin";
    serviceConfig.ExecStart = [
      ""
      "${pkgs.xdg-desktop-portal-wlr}/libexec/xdg-desktop-portal-wlr -l WARN"
    ];
  };
}
