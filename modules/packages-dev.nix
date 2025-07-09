{ pkgs }:

with pkgs;
[
  cmake
  go
  gcc
  # rustup
  golangci-lint
  graphviz
  pgcli

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
  mangohud
  vulkan-tools
  radeontop

  python3
  ffmpeg

]
