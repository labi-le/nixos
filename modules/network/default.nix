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
  };

  imports = [
    (mkIf cfg.enableProxy (import ./proxy.nix))
    (mkIf cfg.injectHosts (import ./hosts.nix))
    (mkIf cfg.enableFirewall (import ./firewall.nix))
  ];

  config = {
    networking.networkmanager.enable = cfg.enableNetworkManager;
  };
}
