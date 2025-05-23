{ pkgs }:

with pkgs;
[
  postman
  # jetbrains.rust-rover
  jetbrains.phpstorm
  # jetbrains.clion
  # jetbrains.pycharm-professional
  (jetbrains.goland.overrideAttrs (oldAttrs: {
    postFixup =
      (oldAttrs.postFixup or "")
      + ''
        rm -f $out/goland/plugins/go-plugin/lib/dlv/linux/dlv
        ln -s ${delve}/bin/dlv $out/goland/plugins/go-plugin/lib/dlv/linux/dlv
      '';
  }))
]
