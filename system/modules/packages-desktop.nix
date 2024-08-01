{ pkgs }:

with pkgs;
[
  mpv
  obsidian
  google-chrome
  vesktop
  telegram-desktop
  dbeaver-bin
  notepad-next
  stable.openfortivpn
  libreoffice-qt6-still
  glib
  gsettings-desktop-schemas
  ngrok
  postman
  libnotify
  home-manager
  ipset
  inetutils
  xdg-utils
  pavucontrol
  dconf
  go
  wireshark
  (php.buildEnv {
    extensions = { all, enabled }: with all; enabled ++ [ xdebug redis ];
    extraConfig = ''
      xdebug.mode=debug
      xdebug.discover_client_host=1
      xdebug.start_with_request = yes
    '';
  })
  wl-clipboard
  slurp
  wayshot
  grim
  brightnessctl
  (callPackage ../../pkgs/wl-uploader.nix { })
  (callPackage ../../pkgs/belphegor.nix { })
]

