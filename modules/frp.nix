{
  config,
  ...
}:

let
  listenPort = 38392;
  awgBY = 27748;
  danyaPorts = {
    from = 16666;
    to = 16670;
  };
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
      quicBindPort = listenPort;
      auth = {
        method = "token";
        token = "{{ .Envs.FRP_TOKEN }}";
      };
    };
  };

  environment.etc."fail2ban/filter.d/frp-auth.conf".text = ''
    [Init]
    maxlines = 2

    [Definition]
    failregex = ^.*client login info: ip \[<HOST>:\d+\].*\n.*register control error: token in login doesn't match token from configuration.*$
    ignoreregex =
  '';

  services.fail2ban.jails.frp-auth.settings = {
    enabled = true;
    filter = "frp-auth";
    backend = "systemd";
    journalmatch = "_SYSTEMD_UNIT=frp-server.service";
    port = "38392";
    protocol = "udp";
    maxretry = 3;
    findtime = 600;
  };
  networking.firewall.allowedTCPPortRanges = [
    danyaPorts
  ];
  networking.firewall.allowedUDPPorts = [
    listenPort
    awgBY
  ];
  networking.firewall.allowedUDPPortRanges = [
    danyaPorts
  ];
}
