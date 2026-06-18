{ pkgs, ... }:

# nixd is a self-contained binary. Pointing the built-in `nixd` server entry at
# an explicit store path means it works without `nixd` being installed globally.
{
  programs.opencode.settings.lsp.nixd = {
    command = [ "${pkgs.nixd}/bin/nixd" ];
    extensions = [ ".nix" ];
  };
}
