{ config
, lib
, pkgs
, ...
}:

{
  services.resolved.enable = lib.mkForce false;

  services.dnsmasq = {
    enable = true;

    settings = {
      cache-size = 1000;
      interface = "lo";
      bind-interfaces = true;
    };
  };

  networking.networkmanager = {
    enable = true;
    dns = "default";
  };
}
