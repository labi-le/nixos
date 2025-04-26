{ lib
, pkgs
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
          # nix = {
          #   maxMemoryMB = 1024;
          #   flake = {
          #     autoEvalInputs = true;
          #     autoArchive = true;
          #   };
          # };
        };
      };
      # nixd = {
      #   enable = true;
      #   autostart = true;
      #   settings = {
      #     nixpkgs.expr = "import <nixpkgs> { }";
      #     formatting.command = [ "${lib.getExe pkgs.nixfmt-classic}" ];
      #     options = let flake = ''(builtins.getFlake "github:labi-le/nixos")'';
      #     in {
      #       home-manager.expr = ''${flake}.homeConfigurations."pc".options'';
      #       nixvim.expr = "${flake}.packages.${pkgs.system}.nvim.options";
      #       nixos.expr = "${flake}.nixosConfigurations.pc.options";
      #     };
      #   };
      # };
      gopls.enable = true;
      phpactor = {
        enable = true;
      };
      pyright.enable = true;

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
