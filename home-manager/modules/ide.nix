{ pkgs, ... }:

let
  golandCustomDelve = pkgs.jetbrains.goland.overrideAttrs (oldAttrs: {
    postFixup = (oldAttrs.postFixup or "") + ''
      rm -f $out/goland/plugins/go-plugin/lib/dlv/linux/dlv
      ln -s ${pkgs.delve}/bin/dlv $out/goland/plugins/go-plugin/lib/dlv/linux/dlv
    '';

  });
in
{
  home.packages = with pkgs; [
    jetbrains.phpstorm
    jetbrains.clion
    golandCustomDelve
  ];
}
