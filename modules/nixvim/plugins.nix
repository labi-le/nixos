{ pkgs, ... }:
{

  imports = [
    ./barbar.nix
    ./telescope.nix
    ./cmp.nix
    ./lsp.nix
    ./conform.nix
    ./dap.nix
  ];
  programs.nixvim = {
    plugins = {
      dap-go.enable = true;
      cmp-dap.enable = true;
      dap = {
        enable = true;
        configurations = {
          php = [
            {
              name = "Listen for Xdebug";
              type = "php";
              request = "launch";
              port = 9003;
              log = false;
            }
          ];
        };
      };
      friendly-snippets.enable = true;
      luasnip = {
        enable = true;
      };
      lsp-format.enable = true;
      transparent = {
        enable = true;
      };
      nix.enable = true;
      auto-save.enable = true;
      auto-session.enable = true;
      comment.enable = true;
      # double shift menu
      web-devicons.enable = true;
      treesitter.enable = true;
      lsp-lines.enable = true;

      precognition.enable = true;
      nvim-autopairs = {
        enable = true;
      };

      treesitter-textobjects = {
        enable = true;

        settings = {
          move = {
            enable = true;
            set_jumps = true;
            goto_next_start = {
              "]]" = {
                query = "@block.outer";
                desc = "Next block start";
              };
              "]m" = {
                query = "@function.outer";
                desc = "Next function start";
              };
            };
            goto_previous_start = {
              "[[" = {
                query = "@block.outer";
                desc = "Previous block start";
              };
              "[m" = {
                query = "@function.outer";
                desc = "Previous function start";
              };
            };
          };
        };
      };

    };
    extraPlugins = with pkgs; [
      vimPlugins.vim-visual-multi
      vimPlugins.tiny-inline-diagnostic-nvim
    ];
    extraPackages = with pkgs; [
      ripgrep
      fd
      delve
      go
    ];

    extraConfigLua = ''
      vim.g.transparent_enabled = true

      vim.api.nvim_create_autocmd("CursorHold", {
        callback = function()
          vim.diagnostic.open_float(nil, { focus = false })
        end
      })

      vim.opt.updatetime = 500
    '';
  };

}
