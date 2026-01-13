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
  xdg-utils
  dconf

  wl-uploader

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
  mangohud

  # audacity
  ayugram-desktop
  vlc
]
