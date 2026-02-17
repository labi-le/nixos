{ lib, config, ... }:

with lib;

let
  cfg = config.network;
in
{
  options.network = {
    injectHosts = mkOption {
      type = types.bool;
      default = false;
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
  };

  imports = [
    ./proxy.nix
    ./hosts.nix
    ./firewall.nix
    ./dns.nix
  ];

  config = {
    networking.networkmanager.enable = cfg.enableNetworkManager;
    networking.firewall.enable = cfg.enableFirewall;
    networking.enableIPv6 = cfg.enableIPv6;
  };
}
