{ pkgs, ... }:

{
  xdg.portal.enable = true;
  xdg.portal.extraPortals = with pkgs; [
    xdg-desktop-portal-wlr
    # xdg-desktop-portal-gtk
  ];
  programs.xwayland.enable = true;
  xdg.portal.config.common.default = "*";

  # xdpw logs at ERROR by default, which hides the one message that matters
  # when a screencast dies ("pipewire: out of buffers"). WARN costs nothing:
  # a healthy stream prints nothing at all.
  systemd.user.services.xdg-desktop-portal-wlr = {
    overrideStrategy = "asDropin";
    serviceConfig.ExecStart = [
      ""
      "${pkgs.xdg-desktop-portal-wlr}/libexec/xdg-desktop-portal-wlr -l WARN"
    ];
  };
}
