{
  programs.nixvim.plugins.transparent.enable = true;
  programs.nixvim.plugins.codeium-nvim.enable = true;
  programs.nixvim.plugins.cmp.enable = true;

  programs.nixvim.plugins = {
    lsp = {
      enable = true;
      servers = {
        nil_ls.enable = true;
      };
    };
  };
}
