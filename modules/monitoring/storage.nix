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
              summary = "ZFS pool 'data' is not ONLINE on server: run 'zpool status -v data' to see which member degraded, faulted, or is offline.";
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
              summary = "ZFS pool 'data' is over 80% allocated on server: run 'zfs list -o name,used,avail,refer data' and 'zpool list data' to plan expansion or pruning before performance degrades.";
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
              summary = "Root filesystem is below 15% free on server: run 'df -h /' -- the NVMe is DRAM-less and write throughput collapses once it runs low on free blocks to erase, so this is a performance alert as much as a capacity one.";
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
            uid = "storage-backup-filling";
            title = "Backup disk (/backup) is below 15% free";
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
                  expr = ''node_filesystem_avail_bytes{mountpoint="/backup"} / node_filesystem_size_bytes{mountpoint="/backup"}'';
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
              summary = "Backup disk '/backup' (the only copy of the torrent data) is below 15% free on server: run 'df -h /backup' and prune or expand before it fills.";
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
              summary = "SMART status reports failure on device '{{ $labels.device }}' on server: run 'smartctl -a /dev/disk/by-id/{{ $labels.device }}' immediately and plan replacement.";
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
              summary = "NVMe media error count grew in the last 24h on server: run 'smartctl -a /dev/disk/by-id/{{ $labels.device }}' to inspect the current count and trend.";
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
              summary = "zfs_exporter is not exporting metrics on server: check 'systemctl status prometheus-zfs-exporter' and 'journalctl -u prometheus-zfs-exporter -n 50'.";
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
              summary = "smartctl_exporter is not exporting metrics on server: SMART monitoring is blind, not that a drive is failing. Check 'systemctl status prometheus-smartctl-exporter' and 'journalctl -u prometheus-smartctl-exporter -n 50'.";
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
  };
}
