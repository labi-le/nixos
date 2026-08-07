{ config, ... }:

# Native tidal-syncer daemon, replacing the hand-driven docker-compose checkout at
# /home/labile/projects/tidal-syncer. The module itself ships from the app's own
# repo (inputs.tidal-syncer.nixosModules.default) so its options cannot drift from
# internal/config; this file carries only this host's values and the secret.
#
# It supersedes inputs.tidal-syncer.nixosModules.monitoring: dashboard.enable
# provisions the same Prometheus job and Grafana dashboard, but derives the scrape
# target from metrics.* instead of hardcoding 127.0.0.1:9101. Importing both would
# define job_name "tidal-syncer" twice and fail promtool at build time.
{
  # Consumed through systemd LoadCredential, which PID 1 reads as root before the
  # unit drops privileges, so the file needs no owner of its own and the service
  # user never opens it -- same reasoning as ./monitoring/contact-points.nix.
  age.secrets.tidal-syncer = {
    file = ../secrets/tidal-syncer.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  services.tidal-syncer = {
    enable = true;

    # The identity that already owns the library and the old ./data directory
    # (docker-compose ran as PUID/PGID=1000:100). Reusing it avoids a chown -R over
    # ~250 artist directories that ./drive.nix also NFS-exports to the LAN.
    user = "labile";
    group = "users";

    # State stays at the module default /var/lib/tidal-syncer, managed as a
    # systemd StateDirectory. The library lives on the ext4 behind /drive.
    paths.music = "/drive/sync/music";

    tidalAuth = {
      clientId = "cgiF7TQuB97BUIu3";
      clientSecretFile = config.age.secrets.tidal-syncer.path;
    };

    scope.favorites = {
      tracks = true;
      albums = true;
      playlists = true;
    };

    # timeZone is deliberately left null: the window is evaluated against the
    # process's local clock, and an unset TZ makes Go read /etc/localtime, i.e.
    # time.timeZone from ./locale.nix (Europe/Moscow) -- the same zone the
    # container pinned explicitly.
    daemon = {
      mode = "time_window";
      timeWindow = {
        start = "02:00";
        end = "06:00";
        min = "4h";
        max = "4h";
      };
    };

    log.level = "debug";

    metrics.enable = true;
    dashboard.enable = true;
  };

  # The derived RequiresMountsFor=/drive/sync/music already orders the unit after
  # drive.automount, but that only proves /drive is mounted, and /drive carries an
  # autofs layer on top of the ext4 -- an empty stub would still look mounted. The
  # library itself is what must be present: an empty music root never self-heals,
  # because the skip decision reads only the database and never the disk, so every
  # track keeps counting as done while nothing is downloaded and the favourites
  # .m3u8 export is rewritten from stale paths.
  systemd.services.tidal-syncer.unitConfig.AssertDirectoryNotEmpty = "/drive/sync/music";
}
