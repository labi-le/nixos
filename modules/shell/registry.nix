# Registers this repo under the `dev` flake registry name so the per-language
# dev shells in ./devshells.nix are callable from any directory, e.g.:
#   nix develop dev#rust
#
# `type = "path"` with a string literal keeps it pointed at the live working
# copy, so the shells reflect uncommitted changes (no frozen store snapshot).
{ config, user, ... }:

{
  nix.registry.dev.to = {
    type = "path";
    path = "${config.users.users.${user.name}.home}/nix";
  };
}
