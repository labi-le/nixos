{ lib, config, ... }:

let
  cfg = config.network;
in
{
  options.network = {
    injectHosts = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable or disable injecting host.";
    };

    enableProxy = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable or disable proxy";
    };

    enableFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable or disable firewall";
    };

    enableNetworkManager = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable or disable NetworkManager";
    };

  };

  imports = [
    (lib.mkIf cfg.enableProxy (import ./proxy.nix))
    (lib.mkIf cfg.injectHosts (import ./hosts.nix))
  ];

  config =
    lib.mkIf cfg.enableNetworkManager { networking.networkmanager.enable = cfg.enableNetworkManager; }
    // lib.mkIf cfg.enableFirewall { networking.firewall.enable = cfg.enableFirewall; };

}

