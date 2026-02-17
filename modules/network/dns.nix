{ ... }:
{
  services.resolved = {
    enable = true;
    settings = {
      Resolve = {
        # DNS = [ "192.168.1.1" ];
        DNS = null;
        Domains = [ "~." ];

        DNSSEC = "false";
        FallbackDNS = null;
      };
    };
  };

}
