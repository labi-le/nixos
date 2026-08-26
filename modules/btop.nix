{ config, lib, pkgs, ... }:
with lib;

let
  cfg = config.services.btop;
  configFile = pkgs.writeText "btop.conf" ''
    show_swap = True
  '';
in
{
  options.services.btop = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Deploy the btop user config (show swap) for the primary user, for hosts without Home Manager.";
    };

    user = mkOption {
      type = types.str;
      default = "labile";
      description = "User whose btop config this module manages.";
    };
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d /home/${cfg.user}/.config/btop 0755 ${cfg.user} - - -"
      "L+ /home/${cfg.user}/.config/btop/btop.conf - - - - ${configFile}"
    ];
  };
}
