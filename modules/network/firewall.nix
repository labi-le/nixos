{ config, lib, ... }:

lib.mkIf config.network.enableFirewall {

  environment.etc."fail2ban/filter.d/nginx-404.conf".text = ''
    [Definition]
    failregex = ^<HOST> -.* "(GET|POST|HEAD).*HTTP.*" 404 .*$
    ignoreregex = \.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$
  '';

  networking.firewall = {
    enable = true;
    logRefusedConnections = false;
    rejectPackets = false;
  };

  services.fail2ban = {
    enable = true;
    maxretry = 5;
    ignoreIP = [
      "10.0.0.0/8"
      "172.16.0.0/12"
      "192.168.0.0/16"
    ];
    bantime = "24h";
    bantime-increment = {
      enable = true;
      formula = "ban.Time * math.exp(float(ban.Count+1)*banFactor)/math.exp(1*banFactor)";
      maxtime = "168h";
      overalljails = true;
    };
    jails = {

      nginx-botsearch = {
        settings = {
          enabled = true;
          filter = "nginx-botsearch";
          logpath = "/var/log/nginx/access.log";
          backend = "auto";
          maxretry = 2;
        };
      };

      nginx-bad-request = {
        settings = {
          enabled = true;
          filter = "nginx-bad-request";
          logpath = "/var/log/nginx/access.log";
          backend = "auto";
        };
      };

      nginx-scan-404 = {
        settings = {
          enabled = true;
          filter = "nginx-404";
          logpath = "/var/log/nginx/access.log";
          backend = "auto";
          maxretry = 5;
          findtime = 60;
          bantime = "5h";
        };
      };
    };
  };
}
