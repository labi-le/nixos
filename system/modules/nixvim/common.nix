{
  programs.nixvim = {
    enable = true;
    colorschemes.catppuccin.enable = true;
  };

  programs.nixvim.opts = {
    number = true;
    cursorline = true;
  };
}
