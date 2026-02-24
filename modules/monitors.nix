{ lib, config, ... }:

with lib;

{
  options = {
    monitors = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            mode = mkOption { type = types.str; };
            geometry = mkOption { type = types.str; };
            position = mkOption { type = types.str; };
            transform = mkOption {
              type = types.nullOr types.str;
              default = null;
            };
          };
        }
      );
      default = { };
    };

    monitorFinder = mkOption {
      type = types.raw;
      readOnly = true;
      default =
        pos:
        let
          found = filterAttrs (n: v: v.position == pos) config.monitors;
          names = attrNames found;
        in
        if names == [ ] then builtins.throw "Monitor '${pos}' not found" else head names;
    };
  };
}
