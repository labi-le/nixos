{ osConfig, pkgs, ... }:

{
  programs.ghostty = {
    enable = osConfig.terminal.name == "ghostty";
    package = (pkgs.extend (_final: prev: {
      gtk4 = prev.gtk4.overrideAttrs (old: {
        patches = old.patches ++ [ ../../pkgs/gtk-8446-wayland-clipboard.patch ];
      });
    })).ghostty;
    settings = {
      class = osConfig.terminal.appId;
    };
  };
}
