# Shared semantic code indexer (index-repo). Only pulled in for withHomeManager
# hosts. Uses the prebuilt release binary from the flake (pkgs.index-repo, set in
# overlays.nix) instead of building from source.
{ inputs, pkgs, ... }:
{
  imports = [ inputs.index-repo.nixosModules.default ];

  services.index-repo = {
    enable = true;
    host = "192.168.1.2";
    package = pkgs.index-repo;
  };
}
