{ config, ... }:

let
  isServer = config.networking.hostName == "server";
  
  serverModules = [
    ./docker.nix
    ./shell.nix
    ./boot.nix
    ./logind.nix
    ./nixvim
    ./packages-server.nix
  ];

  desktopModules = [
    ./docker.nix
    ./shell.nix
    ./logind.nix
    ./sound.nix
    ./boot.nix
    ./greeter.nix
    ./packages.nix
    ./nixvim
    ./network
    ./thunar.nix
    ./polkit.nix
    ./uxplay.nix
    ./wayland.nix
  ];

in
{
  imports = if isServer then serverModules else desktopModules;
}
