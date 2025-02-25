{ pkgs }:

with pkgs;
[
  go
  gcc
  golangci-lint
  graphviz
  pgcli

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

  # Пакеты из home-manager/modules/ide.nix
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

