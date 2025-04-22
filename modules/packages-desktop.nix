{ pkgs }:

with pkgs;
[
  obsidian
  vesktop
  libreoffice-qt6-still
  glib
  gsettings-desktop-schemas
  libnotify
  home-manager
  ipset
  xdg-utils
  pavucontrol
  dconf

  wireshark
  (php.buildEnv {
    extensions =
      { all, enabled }:
        with all;
        enabled
        ++ [
          xdebug
          redis
        ];
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

  (callPackage ./pkgs/wl-uploader.nix { })
  belphegor

  (google-chrome.override {
    commandLineArgs = [
      "--enable-features=AcceleratedVideoEncoder"
      "--ignore-gpu-blocklist"
      "--enable-zero-copy"
    ];
  })

  pcsx2
  qbittorrent

  audacity
  alsa-scarlett-gui
  patchage
  qpwgraph
  alsa-utils

  ayugram-desktop
]
