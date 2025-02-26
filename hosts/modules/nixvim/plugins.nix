{ pkgs, ... }:

{
  programs.nixvim = {

    plugins = {
      lsp = {
        enable = true;
        servers = {
          nil_ls.enable = true;
          gopls.enable = true;
        };
      };

      lsp-format.enable = true;
      transparent.enable = true;
      nix.enable = true;
      auto-save.enable = true;
      auto-session.enable = true;
      comment.enable = true;
      indent-blankline.enable = true;
      lsp-lines.enable = true;

      telescope = {
        enable = true;
      };
      web-devicons.enable = true;

    };
    extraPlugins = with pkgs; [
      vimPlugins.vim-visual-multi
    ];


  };
}
