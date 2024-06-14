{ pkgs, ... }:

{
  programs.thunar.enable = true;
  programs.xfconf.enable = true;

  programs.thunar.plugins = with pkgs; [
    xfce.thunar-archive-plugin
    xfce.thunar-volman

  ];

  environment.systemPackages = with pkgs; [
    xarchiver
  ];

  services.gvfs.enable = true;
  services.tumbler.enable = true;
}
