{ pkgs }:

with pkgs;
[
  obsidian
  vesktop
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
  wf-recorder

  (callPackage ../../pkgs/wl-uploader.nix { })
  (callPackage ../../pkgs/belphegor.nix { })
  (callPackage ../../pkgs/ea-disable-overlay.nix { })

  google-chrome
  thunderbird

  zoom-us
  telegram-desktop

  pcsx2
  mangohud
  bottles
  vulkan-tools
  radeontop

  qbittorrent

  audacity
  alsa-scarlett-gui
  patchage
  qpwgraph
  pwvucontrol
]

