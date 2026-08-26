{ config, ... }:

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
in
{
  services.unbound = {
    enable = true;
    resolveLocalQueries = false;
    enableRootTrustAnchor = true;
    localControlSocketPath = "/run/unbound/unbound.ctl";

    settings = {
      server = {
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
    serviceConfig.SupplementaryGroups = [ tlsGroup ];
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
