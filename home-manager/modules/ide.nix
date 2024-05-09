{ pkgs
, ...
}:

{
  home.packages = with pkgs.unstable.jetbrains; [
    goland
    phpstorm
  ];
}
