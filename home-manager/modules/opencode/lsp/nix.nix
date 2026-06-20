{ pkgs, ... }:

{
  home.packages = [ pkgs.nixd ];

  programs.opencode.settings.lsp.nixd = {
    command = [ "${pkgs.nixd}/bin/nixd" ];
    extensions = [ ".nix" ];
  };
}
