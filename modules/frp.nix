{ config, lib, pkgs, ... }:

let
  frpPort = 38392;
in
{
  age.secrets.frp = {
    file = ../secrets/frp.age;
    owner = "frp";
    group = "frp";
    mode = "0400";
  };

  services.frp = {
    enable = true;
    role = "server";
    settings = {
      bindAddr = "0.0.0.0";
      bindPort = frpPort;
      auth = {
        method = "token";
        token = "{{ .Envs.FRP_TOKEN }}";
      };
    };
  };

  systemd.services.frp.serviceConfig.EnvironmentFile = config.age.secrets.frp.path;

  networking.firewall.allowedTCPPorts = [ frpPort ];
}
