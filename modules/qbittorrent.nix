{ user, ... }:

{
  networking.firewall = {
    allowedTCPPorts = [ 6881 ];
    allowedUDPPorts = [ 6881 ];
  };
  services.qbittorrent = {
    enable = true;
    # user = "qbittorrent";
    # group = "qbittorrent";

    torrentingPort = 6881;
    webuiPort = 7000;

    # openFirewall = true;

    serverConfig = {
      LegalNotice.Accepted = true;

      Preferences = {
        Connection = {
          PortRangeMin = 6881;
        };

        Downloads.SavePath = "/hdd4tb/torrents";

        WebUI = {
          Username = user.name;
          Password_PBKDF2 = "@ByteArray(bDNS6PvLzDjP0ifJ+jQwQw==:pj88WRhAEpZxan4Q1RhYT8bO8mHyrahxvbtgq0QM0nzKOHd9YTzY/O7eV4kQe4jp+am9G8l7qQIHmMm948OBpQ==)";
        };

      };
      BitTorrent = {
        MaxConnecsPerTorrent = -1;
        Session = {
          DefaultSavePath = "/hdd4tb/torrents";
          MaxActiveCheckingTorrents = -1;
          MaxActiveDownloads = -1;
          MaxActiveTorrents = -1;
          MaxActiveUploads = -1;
          MaxConnections = -1;

          MaxConnectionsPerTorrent = -1;
          MaxUploadsPerTorrent = -1;
          MaxUploads = -1;

        };
      };
    };
  };

  systemd.services.qbittorrent.unitConfig = {
    RequiresMountsFor = "/hdd4tb/torrents";
    AssertPathIsMountPoint = "/hdd4tb";
    PartOf = [ "hdd4tb.mount" ];
  };
}
