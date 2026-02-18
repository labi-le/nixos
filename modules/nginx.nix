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

      proxy_headers_hash_max_size 1024;
      proxy_headers_hash_bucket_size 128;
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
      "cache.labile.cc" = proxy {
        addr = "http://127.0.0.1:8501";
        internal = true;
      };
      # "gitlab.labile.cc" = proxy { addr = "http://unix:/run/gitlab/gitlab-workhorse.socket"; };
      "logs.labile.cc" = proxy {
        addr = "http://127.0.0.1:8008";
        internal = true;
        websockets = true;
      };
      "gachi-radio.labile.cc" = {
        enableACME = true;
        forceSSL = true;

        locations."/" = {
          proxyPass = "https://radio.gachibass.us.to";
          extraConfig = ''
            proxy_ssl_server_name on;
            proxy_ssl_name radio.gachibass.us.to;
            proxy_set_header Host radio.gachibass.us.to;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            proxy_set_header Accept-Encoding "";

            sub_filter_types
              application/javascript
              text/css
              application/json
              text/plain;


            sub_filter "https://radio.gachibass.us.to" "https://gachi-radio.labile.cc";
            sub_filter "http://radio.gachibass.us.to"  "https://gachi-radio.labile.cc";
            sub_filter "radio.gachibass.us.to"         "gachi-radio.labile.cc";

            sub_filter_once off;
          '';
        };

        locations."/fisting" = {
          proxyPass = "https://radio.gachibass.us.to/fisting";
          extraConfig = ''
            proxy_ssl_server_name on;
            proxy_ssl_name radio.gachibass.us.to;
            proxy_set_header Host radio.gachibass.us.to;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            proxy_connect_timeout 5s;
            proxy_send_timeout    30s;
            proxy_read_timeout    600s;

            proxy_buffering off;
            proxy_request_buffering off;

            proxy_set_header Accept-Encoding "";

            proxy_intercept_errors on;
          '';
        };
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
    description = "Update Nginx IP whitelist using dig";
    wantedBy = [ "multi-user.target" ];
    script = ''
      #!/bin/sh
      MY_IP=$(${pkgs.dnsutils}/bin/dig +short external.lan)

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
