{ ... }:
{
  services.syncthing = {
    enable = true;

    guiAddress = "0.0.0.0:8384";
    overrideDevices = false;
    overrideFolders = true;

    settings = {
      folders = {
        "/drive/sync/media" = {
          id = "media";
          type = "sendreceive";
          rescanIntervalS = 3600;
          fsWatcherEnabled = true;
          fsWatcherDelayS = 10;
        };

        "/drive/sync/obsidian" = {
          id = "obsidian";
          type = "sendreceive";
          rescanIntervalS = 3600;
          fsWatcherEnabled = true;
          fsWatcherDelayS = 10;
        };
      };

      options = {
        globalAnnounceEnabled = false;
        localAnnounceEnabled = true;
        relaysEnabled = false;
        natEnabled = false;
        urAccepted = -1;
        limitBandwidthInLan = false;
        setLowPriority = true;
        crashReportingEnabled = true;
        minHomeDiskFree = {
          unit = "%";
          value = 1;
        };
      };
    };
  };

  networking.firewall = {
    allowedTCPPorts = [
      22000
    ];
    allowedUDPPorts = [
      22000
    ];
  };

  users.users.labile.extraGroups = [ "syncthing" ];
}
