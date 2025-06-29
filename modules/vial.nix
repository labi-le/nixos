{ pkgs, ... }:

{
  services.udev.packages = [ pkgs.via ];
}
