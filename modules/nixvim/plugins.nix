{ pkgs, ... }: {

  imports = [ ./barbar.nix ./telescope.nix ./cmp.nix ./lsp.nix ./conform.nix ];
  programs.nixvim = {
    plugins = {
      friendly-snippets.enable = true;
      luasnip = { enable = true; };
      lsp-format.enable = true;
      transparent = { enable = true; };
      nix.enable = true;
      auto-save.enable = true;
      auto-session.enable = true;
      comment.enable = true;
      # double shift menu
      web-devicons.enable = true;
      treesitter.enable = true;
      lsp-lines.enable = true;

      nvim-autopairs = { enable = true; };

      treesitter-textobjects = {
        enable = true;

        move = {
          enable = true;
          gotoNextStart = {
            "]]" = "@block.outer";
            "]m" = "@function.outer";
          };
          gotoPreviousStart = {
            "[[" = "@block.outer";
            "[m" = "@function.outer";
          };
        };
      };

    };
    extraPlugins = with pkgs; [
      vimPlugins.vim-visual-multi
      vimPlugins.tiny-inline-diagnostic-nvim
    ];
    extraPackages = with pkgs; [ ripgrep fd ];

    extraConfigLua = ''
      vim.g.transparent_enabled = true
    '';
  };

}
