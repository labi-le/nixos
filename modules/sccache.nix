{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.sccache ];

  systemd.services.sccache = {
    description = "sccache compiler cache server";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "simple";
      User = "labile";
      Group = "users";
      CacheDirectory = "sccache";
      RuntimeDirectory = "sccache";
      RuntimeDirectoryMode = "0755";
      ExecStart = "${pkgs.sccache}/bin/sccache";
      Restart = "on-failure";
      RestartSec = "5s";
    };
    environment = {
      SCCACHE_CACHE_SIZE = "20G";
      SCCACHE_DIR = "/var/cache/sccache";
      SCCACHE_IDLE_TIMEOUT = "0";
      SCCACHE_NO_DAEMON = "1";
      SCCACHE_SERVER_UDS = "/run/sccache/sccache.sock";
      SCCACHE_START_SERVER = "1";
    };
  };
}
