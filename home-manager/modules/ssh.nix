{ ... }:

{
  programs.ssh = {
    enable = true;

    matchBlocks = {
      "pet" = {
        hostname = "192.168.1.2";
      };

      "vpn" = {
        hostname = "wg.labile.cc";
        user = "root";
      };
    };
  };
}
