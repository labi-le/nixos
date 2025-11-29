{ pkgs, ... }:

let
  customThunarArchivePlugin = pkgs.xfce.thunar-archive-plugin.overrideAttrs (oldAttrs: {
    postInstall = (oldAttrs.postInstall or "") + ''
      rm -rf $out/libexec/thunar-archive-plugin
      mkdir -p $out/libexec/thunar-archive-plugin
      ln -s ${pkgs.xarchiver}/libexec/thunar-archive-plugin/* $out/libexec/thunar-archive-plugin/
    '';
  });
in
{
  programs = {
    thunar = {
      enable = true;
      plugins = [
        customThunarArchivePlugin
        pkgs.xfce.thunar-volman
      ];

    };
  };

  services = {
    tumbler.enable = true;
    gvfs.enable = true;
  };

  environment.systemPackages = [ pkgs.file-roller ];
}
