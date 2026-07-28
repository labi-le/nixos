{
  lib,
  pkgs,
  config,
  ...
}:

let
  ipWhiteList = "/var/lib/nginx/ip_whitelist.conf";
in

{
  imports = [ ./zerossl.nix ];

  networking.firewall.allowedTCPPorts = [
    80
    443
    38264
  ];
  # Rotation was off, so access.log reached 300 MB / 742k lines since Oct 2025
  # and kept every leaked secret path in it indefinitely. Module defaults apply
  # (weekly, 26 kept, compressed, USR1 to reopen).
  services.logrotate.settings.nginx.enable = true;

  environment.etc."fail2ban/filter.d/nginx-404.conf".text = ''
    [Definition]
    failregex = ^<HOST> -.* "(GET|POST|HEAD).*HTTP.*" 404 .*$
    ignoreregex = \.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$
  '';

  services.fail2ban.jails = {
    nginx-botsearch.settings = {
      enabled = true;
      filter = "nginx-botsearch";
      logpath = "/var/log/nginx/access.log";
      backend = "auto";
      maxretry = 2;
    };
    nginx-bad-request.settings = {
      enabled = true;
      filter = "nginx-bad-request";
      logpath = "/var/log/nginx/access.log";
      backend = "auto";
    };
    nginx-scan-404.settings = {
      enabled = true;
      filter = "nginx-404";
      logpath = "/var/log/nginx/access.log";
      backend = "auto";
      maxretry = 5;
      findtime = 60;
      bantime = "5h";
    };
  };

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
        {
          addr,
          internal ? false,
          websockets ? false,
          ...
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
      # Sub Store: the UI and the whole admin API sit behind the IP whitelist,
      # but subscription links must stay reachable from anywhere -- clients fetch
      # them over mobile networks. Only the backend's /download/ route is public,
      # matched by shape (32-hex prefix) so the backend path itself stays out of
      # this repo; a wrong prefix just falls through to the SPA.
      subStore =
        { addr }:
        base {
          "/" = {
            proxyPass = addr;
            # Plain 403, NOT the @error404 remap the other internal vhosts use:
            # the nginx-404 jail bans 5x404/60s for 5h at the firewall, and that
            # ban would also cut off the public /download/ links below. Hiding
            # the host is pointless here anyway -- its subscription URLs are
            # handed out publicly.
            extraConfig = ''
              include ${ipWhiteList};
              deny all;
            '';
          };
          "~ ^/[0-9a-f]+/download/" = {
            proxyPass = addr;
          };
        }
        // {
          kTLS = true;
        };
      gachiRadio =
        { rewrite, rewritePlain }:
        {
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

              sub_filter "https://radio.gachibass.us.to" "${rewrite}";
              sub_filter "http://radio.gachibass.us.to"  "${rewrite}";
              sub_filter "radio.gachibass.us.to"         "${rewritePlain}";

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

              proxy_http_version 1.1;
              proxy_set_header Connection "";

              proxy_buffering off;
              proxy_cache off;
              chunked_transfer_encoding on;

              send_timeout 30m;

              proxy_connect_timeout 10s;
              proxy_read_timeout    30m;
              proxy_send_timeout    30m;

              keepalive_timeout 30m;

              proxy_set_header Accept-Encoding "";
              proxy_intercept_errors off;
            '';
          };
        };
    in
    {
      "labile.cc" = proxy { addr = "http://127.0.0.1:7004"; };
      "llm.labile.cc" =
        lib.recursiveUpdate
          (proxy {
            addr = "http://127.0.0.1:27015";
            internal = true;
          })
          {
            locations."/".extraConfig = lib.mkAfter ''
              proxy_read_timeout 300s;
              proxy_connect_timeout 10s;
              proxy_send_timeout 60s;
            '';
          };
      "local.labile.cc" = proxy { addr = "http://192.168.1.3:8080"; };
      "proto.labile.cc" = proxy { addr = "http://127.0.0.1:51821"; };
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
        # internal = true;
      };
      "ip.labile.cc" = proxy { addr = "http://127.0.0.1:7006"; };
      "sub.labile.cc" = subStore { addr = "http://127.0.0.1:3001"; };
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
      "gachi-radio.labile.cc" = (gachiRadio {
        rewrite = "https://gachi-radio.labile.cc";
        rewritePlain = "gachi-radio.labile.cc";
      }) // {
        enableACME = true;
        forceSSL = true;
      };
      "93.100.194.40" = (gachiRadio {
        rewrite = "http://93.100.194.40:38264";
        rewritePlain = "93.100.194.40:38264";
      }) // {
        listen = [
          {
            addr = "0.0.0.0";
            port = 38264;
          }
        ];
        serverName = "93.100.194.40";
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
