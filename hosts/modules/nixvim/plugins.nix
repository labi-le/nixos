{ lib, inputs, pkgs, ... }:

{
  programs.nixvim = {
    plugins = {
      lsp = {
        enable = true;
        servers = {
          nil_ls = {
            enable = true;
            settings = {
              nix = {
                flake = {
                  autoEvalInputs = true;
                  autoArchive = true;
                };
              };
            };
          };
          nixd = {
            enable = true;
            autostart = true;
            settings = {
              nixpkgs.expr = ''import "${inputs.nixpkgs.outPath}" { }'';
              formatting.command = [ "${lib.getExe pkgs.nixfmt-classic}" ];
              options =
                let flake = ''(builtins.getFlake "github:labi-le/nixos")'';
                in {
                  home-manager.expr =
                    ''${flake}.homeConfigurations."pc".options'';
                  nixvim.expr = "${flake}.packages.${pkgs.system}.nvim.options";
                };
            };

          };
          gopls.enable = true;
          phpactor.enable = true;
          pyright.enable = true;
        };

      };
      cmp = {
        enable = true;
        autoEnableSources = true;
        settings = {
          sources = [
            { name = "nvim_lsp"; }
            { name = "path"; }
            { name = "buffer"; }
            { name = "luasnip"; }
          ];

          mapping = {
            "<C-Space>" = ''
              cmp.mapping(function(_)
              if cmp.visible() then
              cmp.abort()
              else
              cmp.complete()
              end
              end, { 'i', 'c' })
            '';
            "<Up>" = "cmp.mapping.select_prev_item()";
            "<Down>" = "cmp.mapping.select_next_item()";
            "<CR>" = "cmp.mapping.confirm({ select = true })";
            "<Tab>" = ''
              cmp.mapping(function(fallback)
              if cmp.visible() then
              cmp.select_next_item()
              else
              fallback()
              end
              end, { 'i', 's' })'';
          };

          window = {
            completion = {
              border = "rounded";
              winhighlight =
                "Normal:Pmenu,FloatBorder:Pmenu,CursorLine:PmenuSel,Search:None";
            };
          };
        };
      };
      lsp-format.enable = true;
      transparent = { enable = true; };
      nix.enable = true;
      auto-save.enable = true;
      auto-session.enable = true;
      comment.enable = true;
      indent-blankline.enable = true;
      lsp-lines.enable = true;
      bufferline.enable = true;

      telescope = { enable = true; };
      web-devicons.enable = true;

    };
    extraPlugins = with pkgs; [ vimPlugins.vim-visual-multi ];

  };

}
