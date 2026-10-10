{ ... }:

{
  services.grafana.provision.alerting.rules.settings = {
    apiVersion = 1;
    groups = [
      {
        orgId = 1;
        name = "storage";
        folder = "storage";
        interval = "1m";
        rules = [
          {
            uid = "storage-pool-health";
            title = "ZFS pool data is not ONLINE";
            condition = "C";
            data = [
              {
                refId = "A";
                relativeTimeRange = {
                  from = 600;
                  to = 0;
                };
                datasourceUid = "prometheus";
                model = {
                  refId = "A";
                  datasource = {
                    type = "prometheus";
                    uid = "prometheus";
                  };
                  editorMode = "code";
                  expr = ''zfs_pool_health{pool="data"}'';
                  instant = true;
                  range = false;
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                };
              }
              {
                refId = "B";
                relativeTimeRange = {
                  from = 0;
                  to = 0;
                };
                datasourceUid = "__expr__";
                model = {
                  refId = "B";
                  type = "reduce";
                  datasource = {
                    type = "__expr__";
                    uid = "__expr__";
                  };
                  expression = "A";
                  reducer = "last";
                };
              }
              {
                refId = "C";
                relativeTimeRange = {
                  from = 0;
                  to = 0;
                };
                datasourceUid = "__expr__";
                model = {
                  refId = "C";
                  type = "threshold";
                  datasource = {
                    type = "__expr__";
                    uid = "__expr__";
                  };
                  expression = "B";
                  conditions = [
                    {
                      type = "query";
                      evaluator = {
                        type = "gt";
                        params = [ 0 ];
                      };
                    }
                  ];
                };
              }
            ];
            noDataState = "OK";
            execErrState = "KeepLast";
            for = "1m";
            annotations = {
              summary = "a vdev member is degraded, faulted or offline";
              command = "zpool status -v data";
            };
            labels = {
              severity = "critical";
              service = "storage";
            };
            isPaused = false;
            notification_settings = {
              receiver = "telegram-admin";
              group_by = [ "alertname" ];
              group_wait = "30s";
              group_interval = "5m";
              repeat_interval = "1h";
            };
          }
          {
            uid = "storage-pool-filling";
            title = "ZFS pool data is over 80% allocated";
            condition = "C";
            data = [
              {
                refId = "A";
                relativeTimeRange = {
                  from = 600;
                  to = 0;
                };
                datasourceUid = "prometheus";
                model = {
                  refId = "A";
                  datasource = {
                    type = "prometheus";
                    uid = "prometheus";
                  };
                  editorMode = "code";
                  expr = ''zfs_pool_allocated_bytes{pool="data"} / zfs_pool_size_bytes{pool="data"}'';
                  instant = true;
                  range = false;
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                };
              }
              {
                refId = "B";
                relativeTimeRange = {
                  from = 0;
                  to = 0;
                };
                datasourceUid = "__expr__";
                model = {
                  refId = "B";
                  type = "reduce";
                  datasource = {
                    type = "__expr__";
                    uid = "__expr__";
                  };
                  expression = "A";
                  reducer = "last";
                };
              }
              {
                refId = "C";
                relativeTimeRange = {
                  from = 0;
                  to = 0;
                };
                datasourceUid = "__expr__";
                model = {
                  refId = "C";
                  type = "threshold";
                  datasource = {
                    type = "__expr__";
                    uid = "__expr__";
                  };
                  expression = "B";
                  conditions = [
                    {
                      type = "query";
                      evaluator = {
                        type = "gt";
                        params = [ 0.8 ];
                      };
                    }
                  ];
                };
              }
            ];
            noDataState = "OK";
            execErrState = "KeepLast";
            for = "5m";
            annotations = {
              summary = "over 80% allocated — plan expansion or pruning";
              command = "zfs list -o name,used,avail,refer data\nzpool list data";
            };
            labels = {
              severity = "warning";
              service = "storage";
            };
            isPaused = false;
            notification_settings = {
              receiver = "telegram-admin";
              group_by = [ "alertname" ];
              group_wait = "30s";
              group_interval = "5m";
              repeat_interval = "12h";
            };
          }
          {
            uid = "storage-root-filling";
            title = "Root filesystem is below 15% free";
            condition = "C";
            data = [
              {
                refId = "A";
                relativeTimeRange = {
                  from = 600;
                  to = 0;
                };
                datasourceUid = "prometheus";
                model = {
                  refId = "A";
                  datasource = {
                    type = "prometheus";
                    uid = "prometheus";
                  };
                  editorMode = "code";
                  expr = ''node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}'';
                  instant = true;
                  range = false;
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                };
              }
              {
                refId = "B";
                relativeTimeRange = {
                  from = 0;
                  to = 0;
                };
                datasourceUid = "__expr__";
                model = {
                  refId = "B";
                  type = "reduce";
                  datasource = {
                    type = "__expr__";
                    uid = "__expr__";
                  };
                  expression = "A";
                  reducer = "last";
                };
              }
              {
                refId = "C";
                relativeTimeRange = {
                  from = 0;
                  to = 0;
                };
                datasourceUid = "__expr__";
                model = {
                  refId = "C";
                  type = "threshold";
                  datasource = {
                    type = "__expr__";
                    uid = "__expr__";
                  };
                  expression = "B";
                  conditions = [
                    {
                      type = "query";
                      evaluator = {
                        type = "lt";
                        params = [ 0.15 ];
                      };
                    }
                  ];
                };
              }
            ];
            noDataState = "Alerting";
            execErrState = "KeepLast";
            for = "5m";
            annotations = {
              summary = "below 15% free — write throughput collapses once free blocks run out";
              command = "df -h /";
            };
            labels = {
              severity = "warning";
              service = "storage";
            };
            isPaused = false;
            notification_settings = {
              receiver = "telegram-admin";
              group_by = [ "alertname" ];
              group_wait = "30s";
              group_interval = "5m";
              repeat_interval = "6h";
            };
          }
          {
            uid = "storage-tmp-filling";
            title = "Temporary filesystem (/tmp) is at least 90% full";
            condition = "C";
            data = [
              {
                refId = "A";
                relativeTimeRange = {
                  from = 600;
                  to = 0;
                };
                datasourceUid = "prometheus";
                model = {
                  refId = "A";
                  datasource = {
                    type = "prometheus";
                    uid = "prometheus";
                  };
                  editorMode = "code";
                  expr = ''1 - node_filesystem_avail_bytes{mountpoint="/tmp"} / node_filesystem_size_bytes{mountpoint="/tmp"}'';
                  instant = true;
                  range = false;
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                };
              }
              {
                refId = "B";
                relativeTimeRange = {
                  from = 0;
                  to = 0;
                };
                datasourceUid = "__expr__";
                model = {
                  refId = "B";
                  type = "reduce";
                  datasource = {
                    type = "__expr__";
                    uid = "__expr__";
                  };
                  expression = "A";
                  reducer = "last";
                };
              }
              {
                refId = "C";
                relativeTimeRange = {
                  from = 0;
                  to = 0;
                };
                datasourceUid = "__expr__";
                model = {
                  refId = "C";
                  type = "threshold";
                  datasource = {
                    type = "__expr__";
                    uid = "__expr__";
                  };
                  expression = "B";
                  conditions = [
                    {
                      type = "query";
                      evaluator = {
                        type = "gte";
                        params = [ 0.9 ];
                      };
                    }
                  ];
                };
              }
            ];
            noDataState = "Alerting";
            execErrState = "KeepLast";
            for = "5m";
            annotations = {
              summary = "at least 90% full — a full /tmp breaks nginx binary-cache downloads";
              command = "df -h /tmp\nsudo du -xhd1 /tmp";
            };
            labels = {
              severity = "warning";
              service = "storage";
            };
            isPaused = false;
            notification_settings = {
              receiver = "telegram-admin";
              group_by = [ "alertname" ];
              group_wait = "30s";
              group_interval = "5m";
              repeat_interval = "6h";
            };
          }
          {
            uid = "storage-torrents-filling";
            title = "Torrents disk (/torrents) is below 15% free";
            condition = "C";
            data = [
              {
                refId = "A";
                relativeTimeRange = {
                  from = 600;
                  to = 0;
                };
                datasourceUid = "prometheus";
                model = {
                  refId = "A";
                  datasource = {
                    type = "prometheus";
                    uid = "prometheus";
                  };
                  editorMode = "code";
                  expr = ''node_filesystem_avail_bytes{mountpoint="/torrents"} / node_filesystem_size_bytes{mountpoint="/torrents"}'';
                  instant = true;
                  range = false;
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                };
              }
              {
                refId = "B";
                relativeTimeRange = {
                  from = 0;
                  to = 0;
                };
                datasourceUid = "__expr__";
                model = {
                  refId = "B";
                  type = "reduce";
                  datasource = {
                    type = "__expr__";
                    uid = "__expr__";
                  };
                  expression = "A";
                  reducer = "last";
                };
              }
              {
                refId = "C";
                relativeTimeRange = {
                  from = 0;
                  to = 0;
                };
                datasourceUid = "__expr__";
                model = {
                  refId = "C";
                  type = "threshold";
                  datasource = {
                    type = "__expr__";
                    uid = "__expr__";
                  };
                  expression = "B";
                  conditions = [
                    {
                      type = "query";
                      evaluator = {
                        type = "lt";
                        params = [ 0.15 ];
                      };
                    }
                  ];
                };
              }
            ];
            noDataState = "Alerting";
            execErrState = "KeepLast";
            for = "5m";
            annotations = {
              summary = "below 15% free — this data has no other copy";
              command = "df -h /torrents";
            };
            labels = {
              severity = "warning";
              service = "storage";
            };
            isPaused = false;
            notification_settings = {
              receiver = "telegram-admin";
              group_by = [ "alertname" ];
              group_wait = "30s";
              group_interval = "5m";
              repeat_interval = "12h";
            };
          }
          {
            uid = "storage-smart-failure";
            title = "A drive is reporting SMART failure";
            condition = "C";
            data = [
              {
                refId = "A";
                relativeTimeRange = {
                  from = 600;
                  to = 0;
                };
                datasourceUid = "prometheus";
                model = {
                  refId = "A";
                  datasource = {
                    type = "prometheus";
                    uid = "prometheus";
                  };
                  editorMode = "code";
                  expr = ''smartctl_device_smart_status'';
                  instant = true;
                  range = false;
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                };
              }
              {
                refId = "B";
                relativeTimeRange = {
                  from = 0;
                  to = 0;
                };
                datasourceUid = "__expr__";
                model = {
                  refId = "B";
                  type = "reduce";
                  datasource = {
                    type = "__expr__";
                    uid = "__expr__";
                  };
                  expression = "A";
                  reducer = "last";
                };
              }
              {
                refId = "C";
                relativeTimeRange = {
                  from = 0;
                  to = 0;
                };
                datasourceUid = "__expr__";
                model = {
                  refId = "C";
                  type = "threshold";
                  datasource = {
                    type = "__expr__";
                    uid = "__expr__";
                  };
                  expression = "B";
                  conditions = [
                    {
                      type = "query";
                      evaluator = {
                        type = "lt";
                        params = [ 1 ];
                      };
                    }
                  ];
                };
              }
            ];
            noDataState = "OK";
            execErrState = "KeepLast";
            for = "2m";
            annotations = {
              summary = "SMART failure on {{ $labels.device }} — plan replacement";
              command = "smartctl -a /dev/disk/by-id/{{ $labels.device }}";
            };
            labels = {
              severity = "critical";
              service = "storage";
            };
            isPaused = false;
            notification_settings = {
              receiver = "telegram-admin";
              group_by = [ "alertname" ];
              group_wait = "30s";
              group_interval = "5m";
              repeat_interval = "1h";
            };
          }
          {
            uid = "storage-nvme-media-errors";
            title = "NVMe media error count is growing";
            condition = "C";
            data = [
              {
                refId = "A";
                relativeTimeRange = {
                  from = 86400;
                  to = 0;
                };
                datasourceUid = "prometheus";
                model = {
                  refId = "A";
                  datasource = {
                    type = "prometheus";
                    uid = "prometheus";
                  };
                  editorMode = "code";
                  expr = ''increase(smartctl_device_media_errors[24h])'';
                  instant = true;
                  range = false;
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                };
              }
              {
                refId = "B";
                relativeTimeRange = {
                  from = 0;
                  to = 0;
                };
                datasourceUid = "__expr__";
                model = {
                  refId = "B";
                  type = "reduce";
                  datasource = {
                    type = "__expr__";
                    uid = "__expr__";
                  };
                  expression = "A";
                  reducer = "last";
                };
              }
              {
                refId = "C";
                relativeTimeRange = {
                  from = 0;
                  to = 0;
                };
                datasourceUid = "__expr__";
                model = {
                  refId = "C";
                  type = "threshold";
                  datasource = {
                    type = "__expr__";
                    uid = "__expr__";
                  };
                  expression = "B";
                  conditions = [
                    {
                      type = "query";
                      evaluator = {
                        type = "gt";
                        params = [ 0 ];
                      };
                    }
                  ];
                };
              }
            ];
            noDataState = "Alerting";
            execErrState = "KeepLast";
            for = "5m";
            annotations = {
              summary = "media error count grew in the last 24h on {{ $labels.device }}";
              command = "smartctl -a /dev/disk/by-id/{{ $labels.device }}";
            };
            labels = {
              severity = "warning";
              service = "storage";
            };
            isPaused = false;
            notification_settings = {
              receiver = "telegram-admin";
              group_by = [ "alertname" ];
              group_wait = "30s";
              group_interval = "5m";
              repeat_interval = "6h";
            };
          }
          {
            uid = "storage-zfs-exporter-down";
            title = "zfs_exporter is not exporting metrics";
            condition = "C";
            data = [
              {
                refId = "A";
                relativeTimeRange = {
                  from = 600;
                  to = 0;
                };
                datasourceUid = "prometheus";
                model = {
                  refId = "A";
                  datasource = {
                    type = "prometheus";
                    uid = "prometheus";
                  };
                  editorMode = "code";
                  expr = ''up{job="zfs"}'';
                  instant = true;
                  range = false;
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                };
              }
              {
                refId = "B";
                relativeTimeRange = {
                  from = 0;
                  to = 0;
                };
                datasourceUid = "__expr__";
                model = {
                  refId = "B";
                  type = "reduce";
                  datasource = {
                    type = "__expr__";
                    uid = "__expr__";
                  };
                  expression = "A";
                  reducer = "last";
                };
              }
              {
                refId = "C";
                relativeTimeRange = {
                  from = 0;
                  to = 0;
                };
                datasourceUid = "__expr__";
                model = {
                  refId = "C";
                  type = "threshold";
                  datasource = {
                    type = "__expr__";
                    uid = "__expr__";
                  };
                  expression = "B";
                  conditions = [
                    {
                      type = "query";
                      evaluator = {
                        type = "lt";
                        params = [ 1 ];
                      };
                    }
                  ];
                };
              }
            ];
            noDataState = "Alerting";
            execErrState = "KeepLast";
            for = "10m";
            annotations = {
              summary = "metrics stopped — ZFS monitoring is blind";
              command = "systemctl status prometheus-zfs-exporter\njournalctl -u prometheus-zfs-exporter -n 50";
            };
            labels = {
              severity = "warning";
              service = "storage";
            };
            isPaused = false;
            notification_settings = {
              receiver = "telegram-admin";
              group_by = [ "alertname" ];
              group_wait = "30s";
              group_interval = "5m";
              repeat_interval = "6h";
            };
          }
          {
            uid = "storage-smartctl-exporter-down";
            title = "smartctl_exporter is not exporting metrics";
            condition = "C";
            data = [
              {
                refId = "A";
                relativeTimeRange = {
                  from = 600;
                  to = 0;
                };
                datasourceUid = "prometheus";
                model = {
                  refId = "A";
                  datasource = {
                    type = "prometheus";
                    uid = "prometheus";
                  };
                  editorMode = "code";
                  expr = ''up{job="smartctl"}'';
                  instant = true;
                  range = false;
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                };
              }
              {
                refId = "B";
                relativeTimeRange = {
                  from = 0;
                  to = 0;
                };
                datasourceUid = "__expr__";
                model = {
                  refId = "B";
                  type = "reduce";
                  datasource = {
                    type = "__expr__";
                    uid = "__expr__";
                  };
                  expression = "A";
                  reducer = "last";
                };
              }
              {
                refId = "C";
                relativeTimeRange = {
                  from = 0;
                  to = 0;
                };
                datasourceUid = "__expr__";
                model = {
                  refId = "C";
                  type = "threshold";
                  datasource = {
                    type = "__expr__";
                    uid = "__expr__";
                  };
                  expression = "B";
                  conditions = [
                    {
                      type = "query";
                      evaluator = {
                        type = "lt";
                        params = [ 1 ];
                      };
                    }
                  ];
                };
              }
            ];
            noDataState = "Alerting";
            execErrState = "KeepLast";
            for = "10m";
            annotations = {
              summary = "metrics stopped — SMART monitoring is blind (not a drive failure)";
              command = "systemctl status prometheus-smartctl-exporter\njournalctl -u prometheus-smartctl-exporter -n 50";
            };
            labels = {
              severity = "warning";
              service = "storage";
            };
            isPaused = false;
            notification_settings = {
              receiver = "telegram-admin";
              group_by = [ "alertname" ];
              group_wait = "30s";
              group_interval = "5m";
              repeat_interval = "6h";
            };
          }
        ];
      }
    ];
    deleteRules = [
      {
        orgId = 1;
        uid = "storage-backup-filling";
      }
    ];
  };
}
