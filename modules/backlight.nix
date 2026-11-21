{ lib, ... }:

with lib;

{
  options.hardware.backlight = mkOption {
    type = types.bool;
    default = false;
    description = "Whether the host has an internal panel backlight.";
  };
}
