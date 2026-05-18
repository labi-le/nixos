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
            primary = mkOption {
              type = types.bool;
              default = false;
            };
          };
        }
      );
      default = { };
    };

    monitorNameByPosition = mkOption {
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

    primaryMonitor = mkOption {
      type = types.raw;
      readOnly = true;
      default =
        let
          found = filterAttrs (_: monitor: monitor.primary or false) config.monitors;
          names = attrNames found;
          monitorName = if names != [ ] then head names else null;
        in
        if monitorName != null then {
          name = monitorName;
        } // config.monitors.${monitorName} else null;
    };
  };

  config =
    let
      primaryMonitors = filterAttrs (_: monitor: monitor.primary or false) config.monitors;
      primaryMonitorNames = attrNames primaryMonitors;
    in
    {
      assertions = [
        {
          assertion = builtins.length primaryMonitorNames <= 1;
          message = "Only one monitor can have primary = true. Found: ${concatStringsSep ", " primaryMonitorNames}";
        }
      ];
    };
}
