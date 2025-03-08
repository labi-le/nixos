{ lib, ... }:

with lib;

{
  options.monitors = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        mode = mkOption { type = types.str; };
        geometry = mkOption { type = types.str; };
        position = mkOption { type = types.str; };
        transform = mkOption {
          type = types.nullOr types.str;
          default = null;
        };
      };
    });
    default = { };
    description = "Monitor configuration";
  };
}
