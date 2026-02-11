{ config, lib, ... }:

lib.mkIf config.network.injectHosts {
  networking.hosts = {
    "172.16.0.11" = [ "forms.local.ru" ];
  };

  services.resolved = {
    enable = true;

    settings = {
      Resolve = {
        DNS = [ "192.168.1.1" ];
        Domains = [ "~." ];

        DNSSEC = "false";
        FallbackDNS = [ ];
      };
    };
  };

  networking.networkmanager.dns = "systemd-resolved";
}

