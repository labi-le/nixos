{ pkgs }:

with pkgs;
[
  cmake
  go
  gcc
  rustup
  golangci-lint
  graphviz
  pgcli
  postman
  zoom-us

  wireshark
  (php.buildEnv {
    extensions = { all, enabled }: with all; enabled ++ [ xdebug redis ];
    extraConfig = ''
      xdebug.mode=debug
      xdebug.discover_client_host=1
      xdebug.start_with_request = yes
    '';
  })
  mangohud
  vulkan-tools
  radeontop

  jetbrains.rust-rover
  jetbrains.phpstorm
  jetbrains.clion
  (jetbrains.goland.overrideAttrs (oldAttrs: {
    postFixup = (oldAttrs.postFixup or "") + ''
      rm -f $out/goland/plugins/go-plugin/lib/dlv/linux/dlv
      ln -s ${delve}/bin/dlv $out/goland/plugins/go-plugin/lib/dlv/linux/dlv
    '';
  })
  )
]

