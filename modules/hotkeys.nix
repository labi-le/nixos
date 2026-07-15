{ lib, ... }:

with lib;

{
  options.hotkeys = {
    common = mkOption { type = types.str; default = "Mod4"; };
    additional = mkOption { type = types.str; default = "Mod1"; };
  };

}
