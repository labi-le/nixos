{
  config,
  pkgs,
  lib,
  ...
}:

{
  home.packages = with pkgs.unstable.jetbrains; [
    goland
    phpstorm
  ];
}
