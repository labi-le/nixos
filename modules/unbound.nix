{ config, ... }:

let
  lanInterface = "enp37s0";
  lanAddress = "192.168.1.2";
  lanNetwork = "192.168.1.0/24";
  vpnInterface = "wg0";
  vpnAddress = "10.8.0.1";
  vpnNetwork = "10.8.0.0/24";
  localPort = 5335;
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
        ];

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
        hide-identity = true;
        hide-version = true;
        do-not-query-localhost = true;
        extended-statistics = true;
      };

      auth-zone = [
        {
          name = ''"."'';
          primary = [
            "170.247.170.2"
            "192.5.5.241"
            "193.0.14.129"
            "192.0.32.132"
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
      allowedTCPPorts = [ 53 ];
    };
    "${vpnInterface}" = {
      allowedUDPPorts = [ 53 ];
      allowedTCPPorts = [ 53 ];
    };
  };

  systemd.services.unbound = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };
}
