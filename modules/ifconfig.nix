{ lib
, ...
}:

let
  host = "ip.labile.cc";
  localPort = 7006;
  containerPort = 8080;
in
{
  virtualisation.oci-containers.backend = lib.mkDefault "docker";

  virtualisation.oci-containers.containers.ifconfig = {
    image = "georgyo/ifconfig.io";
    ports = [ "127.0.0.1:${toString localPort}:${toString containerPort}" ];
    environment = {
      HOSTNAME = host;
      FORWARD_IP_HEADER = "X-Real-IP";
    };
  };

  systemd.services.docker-ifconfig.serviceConfig = {
    Restart = lib.mkOverride 90 "always";
    RestartSec = lib.mkOverride 90 "100ms";
    RestartMaxDelaySec = lib.mkOverride 90 "1m";
    RestartSteps = lib.mkOverride 90 9;
  };
}
