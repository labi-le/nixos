{
  config,
  pkgs,
  lib,
  ...
}:

{
  home.packages = with pkgs.jetbrains; [
    goland
    phpstorm
  ];
}
