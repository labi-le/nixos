{ ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    matchBlocks = {
      "pet".hostname = "192.168.1.2";

      "pc".hostname = "192.168.1.3";

      "vpn" = {
        hostname = "185.224.250.119";
        user = "root";
      };

      "router" = {
        hostname = "192.168.1.1";
        user = "root";
      };

      "work".hostname = "10.89.1.20";
    };
  };
}
