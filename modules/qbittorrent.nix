{ ... }:

{
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

        # sudo mkdir -p /var/lib/qbittorrent/downloads
        # sudo chown qbittorrent:qbittorrent /var/lib/qbittorrent/downloads
        Downloads.SavePath = "/drive/torrents";

        WebUI = {
          Username = "labile";
          Password_PBKDF2 = "@ByteArray(bDNS6PvLzDjP0ifJ+jQwQw==:pj88WRhAEpZxan4Q1RhYT8bO8mHyrahxvbtgq0QM0nzKOHd9YTzY/O7eV4kQe4jp+am9G8l7qQIHmMm948OBpQ==)";
        };

      };
      BitTorrent = {
        MaxConnecsPerTorrent = -1;
        Session = {
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
}
