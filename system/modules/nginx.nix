{
  #services.logrotate.enable = true;
  #services.logrotate.settings.nginx = {
  #  path = "/var/log/nginx";
  #  rotate = 10;
  #  frequency = "daily";
  #};

  systemd.services.nginx.serviceConfig.ReadWritePaths = [ "/var/spool/nginx/logs/" ];

  security.acme = {
    acceptTerms = true;
    defaults.email = "i@labile.cc";
  };

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    clientMaxBodySize = "10G";
    appendHttpConfig = ''
      access_log /var/log/nginx/access.log;
      error_log /var/log/nginx/error.log;
    '';
  };

  services.nginx.virtualHosts =
    let
      base = locations: {
        inherit locations;
        forceSSL = true;
        enableACME = true;
      };
      proxy = addr: base {
        "/" = {
          proxyPass = addr;
        };
      };
    in
    {
      "labile.cc" = proxy "http://127.0.0.1:7004";
      "cloud.labile.cc" = proxy "http://127.0.0.1:7009";
      "local.labile.cc" = proxy "http://192.168.1.3:8080";
      "matrix.labile.cc" = proxy "http://127.0.0.1:8008";
      "obsidian.labile.cc" = proxy "http://127.0.0.1:7007";
      "mail.labile.cc" = proxy "http://127.0.0.1:7001";
      "torrent.labile.cc" = proxy "http://127.0.0.1:7000";
      "vaultwarden.labile.cc" = proxy "http://127.0.0.1:7005";
      "_" = {
        listen = [
          { addr = "0.0.0.0"; port = 80; }
        ];
        serverName = "_";
        locations."/" = {
          return = "301 $scheme://labile.cc$request_uri";
        };
      };
    };
}
