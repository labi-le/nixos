{ lib, osConfig, pkgs, ... }:

{
  home.file.".config/autostart/OpenRGB.desktop" = lib.mkIf osConfig.services.hardware.openrgb.enable {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=OpenRGB
      Comment=OpenRGB, for controlling RGB lighting.
      Exec=${pkgs.openrgb}/bin/openrgb --startminimized
      Icon=OpenRGB
      Terminal=false
      Categories=Utility;
      StartupNotify=true
    '';
  };
}
