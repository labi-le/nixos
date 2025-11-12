{ lib
, pkgs
, config
, ...
}:

let
  ipWhiteList = "/var/lib/nginx/ip_whitelist.conf";
in

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
    package = pkgs.angie;
    enable = true;
    recommendedGzipSettings = true;
    # recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    statusPage = true;
    clientMaxBodySize = "10G";
    commonHttpConfig = "
      sendfile on;
      tcp_nopush on;
      tcp_nodelay on;
    
      client_header_timeout 1s;
      client_body_timeout   10s;
      send_timeout          10s;
      keepalive_timeout     10s;
      keepalive_requests    100;
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
        , websockets ? false
        , ...
        }@args:
        let
          ipRestrictionsConfig =
            if internal then
              ''
                include ${ipWhiteList};
                deny all;
                error_page 403 @error404;
              ''
            else
              "";
          locationCfg = {
            proxyPass = addr;
            extraConfig = ipRestrictionsConfig;
          }
          // lib.optionalAttrs websockets {
            proxyWebsockets = true;
          };
          baseCfg = base {
            "/" = locationCfg;
          };
        in
        baseCfg
        // (builtins.removeAttrs args [
          "addr"
          "internal"
          "websockets"
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
      "torrent.labile.cc" = proxy {
        addr = "http://127.0.0.1:7000";
        internal = true;
      };
      "vaultwarden.labile.cc" = proxy {
        addr = "http://127.0.0.1:7005";
        internal = true;
      };
      "sync.labile.cc" = proxy {
        addr = "http://127.0.0.1:8384";
        internal = true;
      };
      # "gitlab.labile.cc" = proxy { addr = "http://unix:/run/gitlab/gitlab-workhorse.socket"; };
      "logs.labile.cc" = proxy {
        addr = "http://127.0.0.1:8008";
        internal = true;
        websockets = true;
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

  systemd.tmpfiles.rules = [
    "f ${ipWhiteList} 0644 nginx nginx - allow 127.0.0.1;\nallow 192.168.1.0/24;"
  ];

  systemd.services.updateNginxIP = {
    description = "Update Nginx IP whitelist using stunclient";
    wantedBy = [ "multi-user.target" ];
    script = ''
      #!/bin/sh
      MY_IP=$(${pkgs.dnsutils}/bin/dig +short external)

      cat <<EOF > ${ipWhiteList}
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
