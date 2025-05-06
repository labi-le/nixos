{ ... }:

{
  services.mako = {
    enable = true;
    settings = {
      font = "Inconsolata 14";
      backgroundColor = "#151718";
      textColor = "#9FCA56";
      borderColor = "#151718";
      anchor = "bottom-right";
      defaultTimeout = 5000;
    };
    criteria = {
      "urgency=high" = {
        textColor = "#CD3F45";
      };
    };
  };
}
