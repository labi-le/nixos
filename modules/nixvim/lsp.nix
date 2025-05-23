{ lib
, pkgs
, inputs
, ...
}:
{
  programs.nixvim.plugins.cmp-nvim-lsp.enable = true;
  programs.nixvim.plugins.lsp = {
    autoLoad = true;
    enable = true;
    servers = {
      nil_ls = {
        enable = true;
        settings = {
          formatting.command = [
            (lib.getExe pkgs.nixfmt-rfc-style)
            "--quiet"
          ];
          nix = {
            maxMemoryMB = 2048;
            # flake = {
            #   # autoEvalInputs = true;
            #   autoArchive = true;
            # };
          };
        };
      };
      gopls.enable = true;
      phpactor = {
        enable = true;
      };
      pyright.enable = true;
      dockerls.enable = true;
    };
    keymaps = {

      lspBuf = {
        "gd" = {
          action = "definition";
        };
        "gD" = {
          action = "declaration";
        };
        "gb" = {
          action = "references";
        };
      };
    };
  };
}
