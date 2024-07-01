{ ... }:

{
  programs.ssh = {
    enable = true;

    matchBlocks = {
      "pet" = {
        hostname = "192.168.1.2";
      };

      "pc" = {
        hostname = "192.168.1.3";
      };

      "vpn" = {
        hostname = "wg.labile.cc";
        user = "root";
      };

      "router" = {
        hostname = "192.168.1.1";
        user = "root";
      };
    };
  };
}
