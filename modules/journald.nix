{
  # SyncIntervalSec: the box hard-hangs without warning, and the default 5m
  # flush would drop the whole tail. 1s costs one fsync per second of idle
  # logging and guarantees the last words before a freeze are on disk.
  services.journald.extraConfig = ''
    Storage=persistent
    SystemMaxUse=1G
    SyncIntervalSec=1s
  '';
}
