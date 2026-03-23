{ config, pkgs, ... }:

{
  stylix.targets.mako.enable = false;

  services.mako = {
    enable = true;
    settings = {
      font = "SF Pro Display 12";
      background-color = "#${config.lib.stylix.colors.base00}44";
      text-color = "#${config.lib.stylix.colors.base05}";

      border-size = 1;
      border-color = "#${config.lib.stylix.colors.base0D}88";

      border-radius = 10;
      padding = 15;
      margin = 20;
      width = 400;
      height = 180;
      anchor = "bottom-right";
      default-timeout = 3000;

      "urgency=high" = {
        text-color = "#${config.lib.stylix.colors.base08}";
        border-color = "#${config.lib.stylix.colors.base08}";
      };
    };
    extraConfig = "";
  };
}
