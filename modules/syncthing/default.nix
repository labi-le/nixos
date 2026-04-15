{ config, lib, ... }:

with lib;

let
  allDevices = import ./devices.nix;
  cfg = config.sync;
in
{
  options.sync = {
    enable = mkEnableOption "Enable sync custom Syncthing module";

    nodeName = mkOption {
      type = types.str;
      example = "server";
      description = "The name of the current node, as defined in devices.nix.";
    };

    user = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        The username of the user that will run the Syncthing service.
        This user will be automatically added to the 'syncthing' group.
        If not set, the default 'syncthing' user will be used.
      '';
      example = "myuser";
    };

    enableCaddy = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Caddy reverse proxy with HTTPS for syncthing UI";
    };

    folders = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            path = mkOption {
              type = types.str;
              description = "Absolute path to the folder on this machine.";
            };
            id = mkOption {
              type = types.str;
              description = "Global Syncthing ID for the folder.";
            };
            sharesWith = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "List of node names (from devices.nix) to share this folder with.";
              example = [
                "notebook"
                "phone"
              ];
            };
          };
        }
      );
      default = { };
    };
  };

  config = mkIf cfg.enable (
    let
      sharedWithNodes = unique (concatMap (folder: folder.sharesWith) (attrValues cfg.folders));
      portMatch = lib.strings.match ".*:([0-9]+)" config.services.syncthing.guiAddress;
      syncthingPort = lib.strings.toInt (lib.head portMatch);
    in
    mkMerge [
      (mkIf cfg.enableCaddy (import ./caddy.nix { inherit config lib; }))
      {
        services.syncthing = {
          enable = true;
          guiAddress = "127.0.0.1:8384";

          settings = {
            gui = {
              insecureSkipHostCheck = true;
            };
            devices = listToAttrs (
              map (nodeName: {
                name = nodeName;
                value = {
                  id = allDevices.${nodeName}.id;
                };
              }) sharedWithNodes
            );

            folders = mapAttrs (path: folderCfg: {
              inherit (folderCfg) id;
              type = "sendreceive";
              devices = folderCfg.sharesWith;
            }) cfg.folders;
          };
        };

        networking.firewall.allowedTCPPorts = [
          22000
          syncthingPort
        ];
        networking.firewall.allowedUDPPorts = [
          22000
          21027
        ];
        networking.hosts = {
          "127.0.0.1" = [ "syncthing" ];
        };
      }

      (mkIf (cfg.user != null) {
        services.syncthing = {
          user = cfg.user;
          configDir = "/home/${cfg.user}/.config/syncthing";
        };

        users.users.${cfg.user}.extraGroups = [ "syncthing" ];
      })
    ]
  );
}
