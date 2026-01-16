{ pkgs, ... }:

{
  programs.alacritty = {
    enable = true;
    settings = {
      font = {
        normal = {
          family = "SF Mono";
          style = "Regular";
        };
        bold = {
          family = "SF Mono";
          style = "Bold";
        };
        size = 16.0;
      };
      window.opacity = 0;
    };
  };

}
