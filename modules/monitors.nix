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
          allNames = attrNames config.monitors;
        in
        if names != [ ] then
          head names
        else if allNames != [ ] then
          head allNames
        else
          builtins.throw "Monitor '${pos}' not found and no other monitors are defined";
    };
  };
}
