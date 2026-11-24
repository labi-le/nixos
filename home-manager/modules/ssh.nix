{ osConfig, ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "pet".HostName = osConfig.network.serverAddress;

      "pc".HostName = "192.168.1.3";

      "vpn" = {
        HostName = "185.224.250.119";
        User = "root";
      };

      "router" = {
        HostName = osConfig.network.lanGateway;
        User = "root";
      };

      "work".HostName = "10.89.1.20";
    };
  };
}
