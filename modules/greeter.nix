{ pkgs, ... }:

let
  # sway is a home-manager package (swayfx plus its gtk wrapper), so no system
  # package ships a wayland-sessions entry for ly to list -- this is that entry.
  # Exec stays PATH-relative on purpose: the NixOS session wrapper sources
  # /etc/profile before exec, so `sway` resolves to the user's home-manager
  # wrapper, the exact binary greetd used to launch. --unsupported-gpu is
  # required on fx516 (NVIDIA proprietary) and inert on the AMD hosts.
  swaySession =
    pkgs.writeTextFile {
      name = "sway-wayland-session";
      destination = "/share/wayland-sessions/sway.desktop";
      text = ''
        [Desktop Entry]
        Type=Application
        Name=Sway
        Comment=i3-compatible Wayland compositor
        Exec=sway --unsupported-gpu
        DesktopNames=sway;X-NIXOS-SYSTEMD-AWARE
      '';
    }
    // {
      providedSessions = [ "sway" ];
    };
in

{
  services.displayManager = {
    sessionPackages = [ swaySession ];

    ly = {
      enable = true;
      settings = {
        animation = "matrix";
        clock = "%F %T";
        hide_version_string = true;
        xinitrc = null;
      };
    };
  };
}
