{
  programs.nixvim.plugins.transparent.enable = true;
  programs.nixvim.plugins.codeium-vim.enable = true;
  programs.nixvim.plugins.nix.enable = true;
  programs.nixvim.plugins.auto-save.enable = true;
  programs.nixvim.plugins.auto-session.enable = true;
  programs.nixvim.plugins.comment.enable = true;
  programs.nixvim.plugins.telescope.enable = true;
  programs.nixvim.plugins.indent-blankline.enable = true;
  programs.nixvim.plugins.lsp-lines.enable = true;

  programs.nixvim.plugins = {
    lsp = {
      enable = true;
      servers = {
        nil_ls.enable = true;
        gopls.enable = true;
      };
    };

    lsp-format = {
      enable = true;
    };

  };
}
