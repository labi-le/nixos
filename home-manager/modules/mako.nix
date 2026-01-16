{ pkgs, ... }:

{
  services.mako = {
    enable = true;
    settings = {
      font = "SF Pro Display 12";
      background-color = "#15171844";
      text-color = "#BD93F9";

      border-size = 1;
      border-color = "#BD93F988";

      border-radius = 10;
      padding = 15;
      margin = 20;
      width = 400;
      height = 180;
      anchor = "bottom-right";
      default-timeout = 3000;

      "urgency=high" = {
        text-color = "#CD3F45";
        border-color = "#CD3F45";
      };
    };
    extraConfig = "";
  };
}
