{ pkgs }:

with pkgs;
[
  obsidian
  vesktop
  libreoffice-qt6-still
  glib
  gsettings-desktop-schemas
  postman
  libnotify
  home-manager
  ipset
  xdg-utils
  pavucontrol
  dconf

  go
  gcc
  golangci-lint
  graphviz

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
  wf-recorder

  (callPackage ../../pkgs/wl-uploader.nix { })
  belphegor

  google-chrome

  zoom-us

  pcsx2
  mangohud
  vulkan-tools
  radeontop

  qbittorrent

  audacity
  alsa-scarlett-gui
  patchage
  qpwgraph
  pwvucontrol
  alsa-utils

  ayugram-desktop
]

