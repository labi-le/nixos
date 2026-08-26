{ config, lib, pkgs, ... }:

let
  lanInterface = "enp37s0";
  lanAddress = "192.168.1.2";
  lanNetwork = "192.168.1.0/24";
  vpnInterface = "wg0";
  vpnAddress = "10.8.0.1";
  vpnNetwork = "10.8.0.0/24";
  localPort = 5335;
  tlsHost = "dns.labile.cc";
  tlsCertDir = "/var/lib/acme/${tlsHost}";
  tlsGroup = "dns-tls";
  tlsPort = 853;
  dohPort = 8053;
  stateDir = config.services.unbound.stateDir;
  rpzDir = "${stateDir}/rpz";
  blockZone = "${rpzDir}/ads.zone";
  blockUrl = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/rpz/pro.txt";
  blockMinRules = 300000;
  adsTag = "ads";

  localAllow = [ ];
  localBlock = [
    "adfox.ru"
    "vk-portal.net"
  ];

  canaries = [
    "work-portal.example"
    "work-portal.example"
    "work-portal.example"
    "work-portal.example"
    "work-portal.example"
    "work-portal.example"
    "work-portal.example"
    "work-portal.example"
    "labile.cc"
    "yandex.ru"
    "mail.ru"
    "vk.com"
    "gosuslugi.ru"
    "sberbank.ru"
    "github.com"
  ];

  zoneHead = ''
    $TTL 3600
    @ IN SOA localhost. root.localhost. 1 3600 1200 604800 3600
    @ IN NS localhost.
  '';

  triggers = action: names:
    lib.concatMapStrings (n: "${n} IN CNAME ${action}\n*.${n} IN CNAME ${action}\n") names;

  seedZoneFile = pkgs.writeText "unbound-rpz-seed.zone" zoneHead;

  localZoneFile = pkgs.writeText "unbound-rpz-local.zone" (
    zoneHead
    + triggers "rpz-passthru." localAllow
    + triggers "." localBlock
  );
in
{
  services.unbound = {
    enable = true;
    resolveLocalQueries = false;
    enableRootTrustAnchor = true;
    localControlSocketPath = "/run/unbound/unbound.ctl";

    settings = {
      server = {
        define-tag = ''"${adsTag}"'';
        module-config = ''"respip validator iterator"'';

        interface = [
          "127.0.0.1@${toString localPort}"
          lanAddress
          vpnAddress
          "${lanAddress}@${toString tlsPort}"
          "${vpnAddress}@${toString tlsPort}"
        ];

        tls-port = tlsPort;
        tls-service-key = ''"${tlsCertDir}/key.pem"'';
        tls-service-pem = ''"${tlsCertDir}/fullchain.pem"'';

        access-control = [
          "127.0.0.0/8 allow"
          "${lanNetwork} allow"
          "${vpnNetwork} allow"
          "0.0.0.0/0 deny"
        ];

        access-control-tag = [
          ''${lanNetwork} "${adsTag}"''
          ''${vpnNetwork} "${adsTag}"''
        ];

        ip-freebind = true;
        do-ip6 = false;

        num-threads = 2;
        so-reuseport = true;
        msg-cache-size = "64m";
        rrset-cache-size = "128m";
        msg-cache-slabs = 4;
        rrset-cache-slabs = 4;
        key-cache-slabs = 4;
        infra-cache-slabs = 4;

        qname-minimisation = true;
        harden-glue = true;
        harden-dnssec-stripped = true;
        harden-below-nxdomain = true;
        harden-referral-path = true;
        harden-algo-downgrade = true;
        aggressive-nsec = true;

        prefetch = true;
        prefetch-key = true;
        serve-expired = true;
        serve-expired-ttl = 86400;
        serve-expired-ttl-reset = true;

        edns-buffer-size = 1232;
        unwanted-reply-threshold = 10000000;
        ratelimit = 1000;
        hide-identity = true;
        hide-version = true;
        do-not-query-localhost = true;
        extended-statistics = true;
        log-replies = true;
      };

      auth-zone = [
        {
          name = ''"."'';
          primary = [
            "192.0.32.132"
            "192.0.47.132"
            "170.247.170.2"
            "192.33.4.12"
            "199.7.91.13"
            "192.5.5.241"
            "193.0.14.129"
          ];
          zonefile = ''"${stateDir}/root.zone"'';
          for-downstream = false;
          for-upstream = true;
          fallback-enabled = true;
        }
      ];

      rpz = [
        {
          name = ''"rpz.local."'';
          zonefile = ''"${localZoneFile}"'';
          tags = ''"${adsTag}"'';
        }
        {
          name = ''"rpz.ads."'';
          zonefile = ''"${blockZone}"'';
          tags = ''"${adsTag}"'';
          rpz-log = true;
          rpz-log-name = ''"${adsTag}"'';
        }
      ];
    };
  };

  networking.firewall.interfaces = {
    "${lanInterface}" = {
      allowedUDPPorts = [ 53 ];
      allowedTCPPorts = [
        53
        tlsPort
      ];
    };
    "${vpnInterface}" = {
      allowedUDPPorts = [ 53 ];
      allowedTCPPorts = [
        53
        tlsPort
      ];
    };
  };

  systemd.services.unbound = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    preStart = ''
      mkdir -p ${rpzDir}
      chmod 0750 ${rpzDir}
      if [ ! -s ${blockZone} ]; then
        install -m 0640 ${seedZoneFile} ${blockZone}
      fi
    '';
    serviceConfig = {
      SupplementaryGroups = [ tlsGroup ];
      LogRateLimitIntervalSec = "30s";
      LogRateLimitBurst = 3000;
    };
  };

  systemd.services.unbound-rpz-update = {
    description = "Refresh the unbound RPZ blocklist";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" "unbound.service" ];
    path = with pkgs; [ curl coreutils gnugrep config.services.unbound.package ];
    serviceConfig = {
      Type = "oneshot";
      User = config.services.unbound.user;
      Group = config.services.unbound.group;
    };
    script = ''
      set -euo pipefail

      new="${rpzDir}/.ads.zone.new"
      trap 'rm -f "$new"' EXIT

      curl -fsSL --max-time 300 --retry 2 -o "$new" ${blockUrl}

      if ! head -n 20 "$new" | grep -vE '^[;!]' | grep 'SOA' > /dev/null; then
        echo "refusing zone without SOA in its header" >&2
        exit 1
      fi

      rules=$(grep -c 'CNAME' "$new")
      if [ "$rules" -lt ${toString blockMinRules} ]; then
        echo "refusing zone with $rules rules, minimum is ${toString blockMinRules}" >&2
        exit 1
      fi

      for canary in ${lib.concatStringsSep " " canaries}; do
        suffix="$canary"
        while [ -n "$suffix" ]; do
          if grep -qE "^(\*\.)?$suffix[[:space:]]+.*CNAME" "$new"; then
            echo "refusing zone: canary $canary is blocked via $suffix" >&2
            exit 1
          fi
          case "$suffix" in
            *.*) suffix=''${suffix#*.} ;;
            *) suffix="" ;;
          esac
        done
      done

      mv -f "$new" ${blockZone}
      trap - EXIT
      unbound-control -s ${config.services.unbound.localControlSocketPath} auth_zone_reload rpz.ads.
      echo "activated $rules rules"
    '';
  };

  systemd.timers.unbound-rpz-update = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      RandomizedDelaySec = "45m";
      Persistent = true;
    };
  };

  services.doh-server = {
    enable = true;
    settings = {
      listen = [ "127.0.0.1:${toString dohPort}" ];
      path = "/dns-query";
      upstream = [ "tcp:127.0.0.1:${toString localPort}" ];
      timeout = 5;
      tries = 2;
      verbose = true;
    };
  };

  systemd.services.doh-server = {
    wants = [ "unbound.service" ];
    after = [ "unbound.service" ];
    serviceConfig = {
      LogRateLimitIntervalSec = "30s";
      LogRateLimitBurst = 3000;
    };
  };

  users.groups.${tlsGroup}.members = [
    config.services.nginx.user
    config.services.unbound.user
  ];

  security.acme.certs."${tlsHost}" = {
    group = tlsGroup;
    reloadServices = [ "unbound" ];
  };
}
