{ pkgs, ... }:

let
  textfileDir = "/var/lib/prometheus-openwrt";
  logDir = "/var/log/openwrt-murmur";

  collector = pkgs.writeShellScript "openwrt-murmur-collector" ''
    exec ${pkgs.python3}/bin/python3 ${./openwrt-murmur-collector.py} \
      --target root@router \
      --router router \
      --output ${textfileDir}/router-murmur.prom
  '';

  logShipper = pkgs.writeShellScript "openwrt-murmur-logshipper" ''
    exec ${pkgs.python3}/bin/python3 ${./openwrt-murmur-logshipper.py} \
      --target root@router \
      --router router \
      --log-dir ${logDir}/router
  '';
in
{
  systemd.tmpfiles.rules = [
    "d ${textfileDir} 0755 labile users -"
    "d ${logDir} 0755 labile users -"
    "d ${logDir}/router 0755 labile users -"
  ];

  systemd.services.openwrt-murmur-collector = {
    description = "Collect OpenWrt and murmur metrics over SSH";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.openssh ];
    serviceConfig = {
      Type = "oneshot";
      User = "labile";
      Group = "users";
      ExecStart = collector;
      TimeoutStartSec = "45s";
      UMask = "0022";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      ReadWritePaths = [ textfileDir ];
      RestrictSUIDSGID = true;
    };
  };

  systemd.timers.openwrt-murmur-collector = {
    description = "Collect OpenWrt and murmur metrics every minute";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "60s";
      AccuracySec = "1s";
      Unit = "openwrt-murmur-collector.service";
    };
  };

  systemd.services.openwrt-murmur-logshipper-router = {
    description = "Stream murmur structured logs and OpenWrt syslog from main router to disk and Loki";
    after = [ "network-online.target" "loki.service" ];
    wants = [ "network-online.target" "loki.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.openssh ];
    serviceConfig = {
      Type = "simple";
      User = "labile";
      Group = "users";
      ExecStart = logShipper;
      Restart = "always";
      RestartSec = "5s";
      UMask = "0022";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      ReadWritePaths = [ logDir ];
      RestrictSUIDSGID = true;
    };
  };

  services.prometheus.exporters.node.extraFlags = [
    "--collector.textfile.directory=${textfileDir}"
  ];

  services.grafana.provision.dashboards.settings.providers = [
    {
      name = "openwrt-murmur";
      type = "file";
      disableDeletion = true;
      folder = "network";
      options = {
        foldersFromFilesStructure = false;
        path = pkgs.runCommand "grafana-openwrt-murmur-dashboard" { } ''
          mkdir -p $out
          cp ${./dashboards/openwrt-murmur.json} $out/openwrt-murmur.json
        '';
      };
    }
  ];
}
