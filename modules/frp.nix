{
  config,
  lib,
  pkgs,
  ...
}:

let
  frpPort = 38392;
in
{
  age.secrets.frp = {
    file = ../secrets/frp.age;
    mode = "0400";
  };

  services.frp.instances.server = {
    enable = true;
    role = "server";
    environmentFiles = [ config.age.secrets.frp.path ];
    settings = {
      bindAddr = "0.0.0.0";
      bindPort = frpPort;
      auth = {
        method = "token";
        token = "{{ .Envs.FRP_TOKEN }}";
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ frpPort ];
  networking.firewall.allowedUDPPorts = [ frpPort ];
}
