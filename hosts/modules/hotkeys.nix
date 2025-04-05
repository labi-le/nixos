{ lib, ... }:

with lib;

{
  options.hotkeys = {
    common = mkOption { type = types.str; };
    additional = mkOption { type = types.str; };
  };

}
