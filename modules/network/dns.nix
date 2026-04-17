{
  config,
  lib,
  pkgs,
  ...
}:

{
  services.resolved.enable = lib.mkForce false;

  services.dnsmasq = {
    enable = true;

    settings = {
      cache-size = 1000;
    };
  };

  networking.networkmanager = {
    enable = true;
    dns = "default";
  };
}
