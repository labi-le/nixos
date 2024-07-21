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
      ssl_stapling off;
      ssl_verify_client on;

    '';
  };

  services.nginx.virtualHosts =
    let
      base = locations: {
        inherit locations;
      };
      proxy = port: base {
        "/".proxyPass = "http://127.0.0.1:" + toString (port) + "/";
      };
    in
    {
      "localhost" = proxy 8080 // { default = true; };
      "labile.cc" = proxy 7004;
      "cloud.labile.cc" = proxy 7009;
      "local.labile.cc" = proxy 8080;
      "matrix.labile.cc" = proxy 8008;
      "obsidian.labile.cc" = proxy 7007;
      "torrent.labile.cc" = proxy 7000;
      "vaultwarden.labile.cc" = proxy 7005;
    };
}
