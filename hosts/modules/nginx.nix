{
  security.acme = {
    acceptTerms = true;
    defaults.email = "i@labile.cc";
  };
  services.logrotate.settings.nginx.enable = false;

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    statusPage = true;

    clientMaxBodySize = "10G";
    commonHttpConfig = "
          map $http_upgrade $connection_upgrade {
          default upgrade;
          '' close;
      }
    ";
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
      proxy =
        addr:
        let
          baseCfg = base {
            "/" = {
              proxyPass = addr;
            };
          };
        in
        baseCfg // { kTLS = true; };
    in
    {
      "labile.cc" = proxy "http://127.0.0.1:7004";
      "local.labile.cc" = proxy "http://192.168.1.3:8080";
      "obsidian.labile.cc" = proxy "http://127.0.0.1:7007";
      "mail.labile.cc" = proxy "http://127.0.0.1:7001";
      "torrent.labile.cc" = proxy "http://127.0.0.1:7000";
      "vaultwarden.labile.cc" = proxy "http://127.0.0.1:7005";
      "sync.labile.cc" = proxy "http://127.0.0.1:7006";
      "logs.labile.cc" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:8008";
          proxyWebsockets = true;
        };
        forceSSL = true;
        enableACME = true;
      };
      "_" = {
        listen = [
          {
            addr = "0.0.0.0";
            port = 80;
          }
        ];
        serverName = "_";
        locations."/" = {
          return = "301 $scheme://labile.cc$request_uri";
        };
      };
    };
}
