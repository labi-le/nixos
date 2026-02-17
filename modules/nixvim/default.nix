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

    highlight = {
      BufferTabpageFill.bg = "none";

      BufferInactive.bg = "none";
      BufferInactiveIndex.bg = "none";
      BufferInactiveMod.bg = "none";
      BufferInactiveSign.bg = "none";
      BufferInactiveTarget.bg = "none";

      BufferCurrent.bg = "none";
      BufferCurrentIndex.bg = "none";
      BufferCurrentMod.bg = "none";
      BufferCurrentSign.bg = "none";
      BufferCurrentTarget.bg = "none";

      BufferVisible.bg = "none";
      BufferVisibleIndex.bg = "none";
      BufferVisibleMod.bg = "none";
      BufferVisibleSign.bg = "none";
      BufferVisibleTarget.bg = "none";
    };
  };

  environment.systemPackages = with pkgs; [ neovide ];
}
