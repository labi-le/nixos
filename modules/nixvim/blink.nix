{ ... }:
{
  programs.nixvim.plugins = {
    blink-cmp = {
      enable = true;
      setupLspCapabilities = true;
      settings = {
        keymap = {
          preset = "super-tab";
        };
        sources = {
          default = [
            "lsp"
            "path"
            "snippets"
            "buffer"
          ];
          providers = {
            lsp = {
              enabled = true;
            };
            buffer = {
              score_offset = -7;
            };
            path = {
              enabled = true;
            };
          };
        };
        completion = {
          accept = {
            auto_brackets = {
              enabled = true;
            };
          };
          documentation = {
            auto_show = true;
          };
        };
        appearance = {
          use_nvim_cmp_as_default = true;
          nerd_font_variant = "normal";
        };
        signature = {
          enabled = true;
        };
      };
    };

    cmp-nvim-lsp = {
      enable = true;
    };
  };
}
