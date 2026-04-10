{ pkgs }:

with pkgs;
[
  obsidian
  vesktop
  libreoffice-fresh
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

  ea-disable-overlay

  opencode

  (python3Packages.buildPythonApplication rec {
    pname = "desloppify";
    version = "0.9.15";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-AXDPIBIvvRba50EQUA5iuXgdfdk/5di8GBlSjFXaPiI=";
    };

    build-system = with python3Packages; [ setuptools ];
    dependencies = with python3Packages; [ tree-sitter tree-sitter-language-pack defusedxml bandit pillow pyyaml ];
    doCheck = false;
  })

]
