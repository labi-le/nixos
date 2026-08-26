{ pkgs, ... }:

{
  programs.btop = {
    enable = true;
    package = pkgs.btop.override { rocmSupport = true; };
    settings = {
      show_swap = true;
    };
  };
}
