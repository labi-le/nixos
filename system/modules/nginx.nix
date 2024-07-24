{
  services.logrotate.enable = true;
  services.logrotate.settings.nginx = {
    path = "/var/log/nginx";
    rotate = 10;
    frequency = "daily";
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

      ssl_certificate /etc/ssl/labile.cc.pem;
      ssl_certificate_key /etc/ssl/labile.cc.key;
      ssl_client_certificate /etc/ssl/cloudflare.crt;
    '';
  };

  services.nginx.virtualHosts =
    let
      base = locations: {
        inherit locations;
        forceSSL = true;
        sslCertificate = "/etc/ssl/labile.cc.pem";
        sslCertificateKey = "/etc/ssl/labile.cc.key";
      };
      proxy = addr: base {
        "/" = {
          proxyPass = addr;
        };
      };
    in
    {
      "labile.cc" = proxy "http://127.0.0.1:7004" // { default = true; };
      "cloud.labile.cc" = proxy "http://127.0.0.1:7009";
      "local.labile.cc" = proxy "http://192.168.1.3:8080";
      "matrix.labile.cc" = proxy "http://127.0.0.1:8008";
      "obsidian.labile.cc" = proxy "http://127.0.0.1:7007";
      "mail.labile.cc" = proxy "http://127.0.0.1:7001";
      "torrent.labile.cc" = proxy "http://127.0.0.1:7000";
      "vaultwarden.labile.cc" = proxy "http://127.0.0.1:7005";
    };
}
