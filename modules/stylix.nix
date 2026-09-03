{ inputs, pkgs, ... }:

{
  disabledModules = [
    "${inputs.stylix}/modules/neovim/nixos.nix"
    "${inputs.stylix}/modules/neovim/nixvim.nix"
  ];

  stylix = {
    enable = true;
    image = ../assets/wallpaper.jpg;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/dracula.yaml";
    polarity = "dark";

    fonts = {
      monospace = {
        package = pkgs.apple-fonts.sf-mono-nerd;
        name = "SFMono Nerd Font";
      };
      sansSerif = {
        package = pkgs.apple-fonts.sf-pro-nerd;
        name = "SFProDisplay Nerd Font";
      };
      serif = {
        package = pkgs.apple-fonts.ny;
        name = "New York";
      };

      sizes = {
        terminal = 14;
      };
    };

    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };

    icons = {
      enable = true;
      package = pkgs.dracula-icon-theme;
      dark = "Dracula";
      light = "Dracula";
    };

    opacity = {
      terminal = 0.5;
      desktop = 0.5;
    };
  };
}
