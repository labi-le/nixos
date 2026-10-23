{
  config,
  lib,
  pkgs,
  inputs,
  user,
  ...
}:

let
  files = import ./settings {
    inherit
      config
      lib
      pkgs
      inputs
      user
      ;
  };
  packages = import ./packages.nix { inherit pkgs; };
  install = import ./install.nix { inherit files lib user; };
in
{
  imports = [
    ./secrets.nix
    ./index-repo.nix
  ];

  programs.omp = packages.programs;
  environment.systemPackages = packages.systemPackages;

  systemd.tmpfiles.rules = install.tmpfiles;
  systemd.user.services = files.mcpServices;
  system.activationScripts.ompConfig = install.activationScript;
}
