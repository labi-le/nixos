{ pkgs, ... }:

let
  textfileDir = "/var/lib/prometheus-openwrt";
  collector = pkgs.writeShellScript "openwrt-murmur-collector" ''
    exec ${pkgs.python3}/bin/python3 ${./openwrt-murmur-collector.py} \
      --target root@openwrt \
      --router openwrt \
      --output ${textfileDir}/openwrt-murmur.prom
  '';
in
{
  systemd.tmpfiles.rules = [
    "d ${textfileDir} 0755 labile users -"
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
      TimeoutStartSec = "40s";
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
