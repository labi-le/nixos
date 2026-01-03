{ pkgs, ... }:

let
  customThunarArchivePlugin = pkgs.thunar-archive-plugin.overrideAttrs (oldAttrs: {
    postInstall = (oldAttrs.postInstall or "") + ''
      rm -rf $out/libexec/thunar-archive-plugin
      mkdir -p $out/libexec/thunar-archive-plugin
      ln -s ${pkgs.xarchiver}/libexec/thunar-archive-plugin/* $out/libexec/thunar-archive-plugin/
    '';
  });
in
{
  programs.thunar = {
    enable = true;
    plugins = [
      customThunarArchivePlugin
      pkgs.thunar-volman
    ];
  };

  services.tumbler.enable = true;
  services.gvfs.enable = true;

  environment.systemPackages = [ pkgs.file-roller ];
}
