{
  config,
  ...
}:

let
  listenPort = 38392;
  awgBY = 27748;
  danyaVNC = 16666;
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
      bindPort = listenPort;
      auth = {
        method = "token";
        token = "{{ .Envs.FRP_TOKEN }}";
      };
    };
  };

  networking.firewall.allowedTCPPorts = [
    listenPort
    danyaVNC
  ];
  networking.firewall.allowedUDPPorts = [
    listenPort
    awgBY
  ];
}
