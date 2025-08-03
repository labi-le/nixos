{ lib, pkgs, ... }:
{
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
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
        { addr
        , internal ? false
        , ...
        }@args:
        let
          ipRestrictionsConfig =
            if internal then
              ''
                include /etc/nginx/ip_whitelist.conf;
                deny all;
                error_page 403 @error404;
              ''
            else
              "";
          locationCfg = {
            proxyPass = addr;
            extraConfig = ipRestrictionsConfig;
          };
          baseCfg = base {
            "/" = locationCfg;
          };
        in
        baseCfg
        // (builtins.removeAttrs args [
          "addr"
          "internal"
        ])
        // {
          kTLS = true;
          extraConfig = lib.optionalString internal ''
            location @error404 {
              return 404;
            }
          '';
        };
    in
    {
      "labile.cc" = proxy { addr = "http://127.0.0.1:7004"; };
      "local.labile.cc" = proxy { addr = "http://192.168.1.3:8080"; };
      "obsidian.labile.cc" = proxy { addr = "http://127.0.0.1:7007"; };
      "mail.labile.cc" = proxy {
        addr = "http://127.0.0.1:7001";
        internal = true;
      };
      "torrent.labile.cc" = proxy { addr = "http://127.0.0.1:7000"; };
      "vaultwarden.labile.cc" = proxy { addr = "http://127.0.0.1:7005"; };
      "sync.labile.cc" = proxy {
        addr = "http://127.0.0.1:8384";
        internal = true;
      };
      "gitlab.labile.cc" = proxy { addr = "http://unix:/run/gitlab/gitlab-workhorse.socket"; };
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

  systemd.services.updateNginxIP = {
    description = "Update Nginx IP whitelist using stunclient";
    wantedBy = [ "multi-user.target" ];
    script = ''
      #!/bin/sh
      MY_IP=$(${pkgs.stuntman}/bin/stunclient stun.l.google.com 19302 | grep 'Mapped address' | awk '{print $3}' | cut -d':' -f1)

      cat <<EOF > /etc/nginx/ip_whitelist.conf
      allow 127.0.0.1;
      allow 192.168.1.0/24;
      allow $MY_IP/32;
      EOF

      systemctl reload nginx
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };

  systemd.timers.updateNginxIP = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
  };
}
