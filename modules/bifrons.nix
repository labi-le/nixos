{ config, pkgs, ... }:

{
  age.secrets.bifrons = {
    file = ../secrets/bifrons.age;
    owner = "bifrons";
    group = "bifrons";
    mode = "0400";
  };

  users.groups.bifrons = { };
  users.users.bifrons = {
    isSystemUser = true;
    group = "bifrons";
  };

  systemd.services.bifrons = {
    description = "YouTube to Music Assistant bridge for the station";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [
      "network-online.target"
      "docker-music-assistant.service"
    ];
    serviceConfig = {
      User = "bifrons";
      Group = "bifrons";
      EnvironmentFile = [
        config.age.secrets.bifrons.path
        config.age.secrets.grafana-telegram.path
      ];
      Environment = [
        "YTDLP=${pkgs.yt-dlp}/bin/yt-dlp"
        "BIFRONS_BIND=127.0.0.1:8096"
      ];
      ExecStart = "${pkgs.python3}/bin/python3 ${./bifrons.py}";
      Restart = "always";
      RestartSec = 5;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };
}
