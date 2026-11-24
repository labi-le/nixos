{ lib, config, ... }:

with lib;

let
  cfg = config.network;
in
{
  options.network = {
    injectHosts = mkOption {
      type = types.bool;
      default = true;
      description = "Enable or disable injecting host.";
    };

    enableProxy = mkOption {
      type = types.bool;
      default = false;
      description = "Enable or disable proxy";
    };

    enableFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Enable or disable firewall";
    };

    enableNetworkManager = mkOption {
      type = types.bool;
      default = true;
      description = "Enable or disable NetworkManager";
    };

    enableIPv6 = mkOption {
      type = types.bool;
      default = false;
      description = "Enable or disable IPv6";
    };

    lanInterface = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Primary wired LAN interface name on this host.";
    };

    wakeOnLan = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Wake-on-LAN on network.lanInterface.";
    };

    lanSubnet = mkOption {
      type = types.str;
      default = "192.168.1.0/24";
      description = "Home LAN IPv4 CIDR.";
    };

    lanGateway = mkOption {
      type = types.str;
      default = "192.168.1.1";
      description = "Home LAN IPv4 gateway and upstream DNS address.";
    };

    serverAddress = mkOption {
      type = types.str;
      default = "192.168.1.2";
      description = "Server LAN IPv4 address.";
    };

    vpnInterface = mkOption {
      type = types.str;
      default = "wg0";
      description = "AmneziaWG tunnel interface name.";
    };

    vpnAddress = mkOption {
      type = types.str;
      default = "10.8.0.1";
      description = "Server IPv4 address inside the VPN tunnel.";
    };

    vpnSubnet = mkOption {
      type = types.str;
      default = "10.8.0.0/24";
      description = "VPN tunnel IPv4 CIDR.";
    };
  };

  imports = [
    ./proxy.nix
    ./hosts.nix
    ./firewall.nix
    ./dns.nix
  ];

  config = {
    assertions = [
      {
        assertion = !cfg.wakeOnLan || cfg.lanInterface != null;
        message = "network.lanInterface must be set when network.wakeOnLan is enabled.";
      }
    ];
    networking.networkmanager.enable = cfg.enableNetworkManager;
    networking.firewall.enable = cfg.enableFirewall;
    networking.enableIPv6 = cfg.enableIPv6;
    networking.interfaces = optionalAttrs (cfg.lanInterface != null && cfg.wakeOnLan) {
      ${cfg.lanInterface}.wakeOnLan.enable = true;
    };
  };
}
