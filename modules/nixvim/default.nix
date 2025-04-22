{ pkgs, ... }:

{
  imports = [
    ./plugins.nix
    ./keymaps.nix
  ];
  programs.nixvim = {
    enable = true;
    colorschemes.catppuccin.enable = true;
    clipboard = {
      register = "unnamedplus";
      providers.wl-copy.enable = true;
    };
    opts = {
      number = true;
      cursorline = true;
    };
  };

  environment.systemPackages = with pkgs; [ neovide ];
}
