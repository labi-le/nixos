{ ... }:
{
  age.secrets.awg-env = {
    file = ./../../secrets/awg/env.age;
    owner = "labile";
    group = "docker";
    mode = "0400";
  };

  networking.firewall = {
    allowedTCPPorts = [
      51821
    ];
    allowedUDPPorts = [
      51820
    ];
  };

  imports = [ ./compose.nix ];
}
