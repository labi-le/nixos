{ ... }:

{
  services.mako = {
    enable = true;
    settings = {
      font = "Inconsolata 14";
      background-color = "#151718";
      text-color = "#9FCA56";
      border-color = "#151718";
      anchor = "bottom-right";
      default-timeout = 5000;
      "urgency=high" = {
        text-color = "#CD3F45";
      };
    };
  };
}
