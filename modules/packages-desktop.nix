{ pkgs }:

with pkgs;
[
  obsidian
  libreoffice
  glib
  gsettings-desktop-schemas
  libnotify
  home-manager
  xdg-utils
  dconf

  (google-chrome.override {
    commandLineArgs = [
      "--enable-features=AcceleratedVideoEncoder"
      "--ignore-gpu-blocklist"
      "--enable-zero-copy"
    ];
  })
  chromium

  pcsx2
  qbittorrent
  postman

  # audacity
  ayugram-desktop
  vlc
  quickemu

  discord-canary
]
