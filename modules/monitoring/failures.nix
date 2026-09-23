{ ... }:

{
  services.grafana.provision.alerting.rules.settings = {
    apiVersion = 1;
    groups = [
      {
        orgId = 1;
        name = "failures";
        folder = "failures";
        interval = "1m";
        rules = [
          {
            uid = "systemd-unit-failed";
            title = "A systemd unit is in the failed state";
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
                  expr = ''node_systemd_unit_state{state="failed"}'';
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
            for = "2m";
            annotations = {
              summary = "systemd unit {{ $labels.name }} is in the failed state on server: run 'systemctl status {{ $labels.name }}' and 'journalctl -u {{ $labels.name }} -n 50' to see why.";
            };
            labels = {
              severity = "critical";
              service = "failures";
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
            uid = "systemd-restart-loop";
            title = "A systemd service is crash-looping";
            condition = "C";
            data = [
              {
                refId = "A";
                relativeTimeRange = {
                  from = 900;
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
                  expr = ''increase(node_systemd_service_restart_total[15m])'';
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
                        params = [ 5 ];
                      };
                    }
                  ];
                };
              }
            ];
            noDataState = "OK";
            execErrState = "KeepLast";
            for = "0s";
            annotations = {
              summary = "systemd service {{ $labels.name }} restarted more than 5 times in the last 15 minutes on server: run 'systemctl status {{ $labels.name }}' and 'journalctl -u {{ $labels.name }} -n 100' to find the crash loop.";
            };
            labels = {
              severity = "critical";
              service = "failures";
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
            uid = "container-restart-loop";
            title = "A Docker container is crash-looping";
            condition = "C";
            data = [
              {
                refId = "A";
                relativeTimeRange = {
                  from = 900;
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
                  expr = ''increase(docker_container_restart_count[15m]) or ((docker_container_restart_count unless docker_container_restart_count offset 15m) + 0)'';
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
                        params = [ 3 ];
                      };
                    }
                  ];
                };
              }
            ];
            noDataState = "OK";
            execErrState = "KeepLast";
            for = "0s";
            annotations = {
              summary = "Docker container {{ $labels.name }} restarted more than 3 times in the last 15 minutes on server: run 'docker inspect {{ $labels.name }}' and 'docker logs --tail 100 {{ $labels.name }}' to see why it is crash-looping.";
            };
            labels = {
              severity = "critical";
              service = "failures";
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
            uid = "container-down";
            title = "A Docker container with an always restart policy is not running";
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
                  expr = ''docker_container_running == 0 and on(name) docker_container_restart_policy_info{policy="always"}'';
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
            for = "5m";
            annotations = {
              summary = "Docker container {{ $labels.name }} is not running on server even though its restart policy is always: run 'docker ps -a --filter name={{ $labels.name }}' and 'docker logs --tail 100 {{ $labels.name }}' to see why it stopped.";
            };
            labels = {
              severity = "critical";
              service = "failures";
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
            uid = "container-unhealthy";
            title = "A Docker container's health check is failing";
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
                  expr = ''docker_container_healthy == 0'';
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
            for = "5m";
            annotations = {
              summary = "Docker container {{ $labels.name }} is reporting an unhealthy health check on server: run 'docker inspect {{ $labels.name }} | jq .State.Health' to see the failing check.";
            };
            labels = {
              severity = "warning";
              service = "failures";
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
            uid = "container-state-stale";
            title = "The Docker container-state exporter stopped updating";
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
                  expr = ''(time() - docker_container_exporter_last_run_timestamp_seconds > 180) or absent(docker_container_exporter_last_run_timestamp_seconds)'';
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
              summary = "The docker-container-state-exporter has not updated its metrics file in over 3 minutes, or has never run, on server: container-state monitoring (container-down, container-unhealthy, container-restart-loop) is blind. Run 'systemctl status docker-container-state-exporter.timer' and 'journalctl -u docker-container-state-exporter -n 50'.";
            };
            labels = {
              severity = "critical";
              service = "failures";
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
            uid = "oom-kill";
            title = "The kernel OOM killer has killed a process";
            condition = "C";
            data = [
              {
                refId = "A";
                relativeTimeRange = {
                  from = 300;
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
                  expr = ''increase(node_vmstat_oom_kill[5m])'';
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
            for = "0s";
            annotations = {
              summary = "The kernel OOM killer has killed a process on server in the last 5 minutes: run 'journalctl -k --grep=\"Out of memory\"' and 'dmesg -T | grep -i \"killed process\"' to identify what was killed, and check the process-exporter dashboard for the memory hog around that time.";
            };
            labels = {
              severity = "critical";
              service = "failures";
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
            uid = "scrape-target-down";
            title = "A Prometheus scrape target is down";
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
                  expr = ''up{job!~"^(zfs|smartctl|tidal-syncer)$"}'';
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
            for = "5m";
            annotations = {
              summary = "Prometheus scrape target job={{ $labels.job }} instance={{ $labels.instance }} is down on server: check that its exporter unit is running (e.g. 'systemctl status prometheus-node-exporter', 'prometheus-nginx-exporter', 'prometheus-process-exporter', 'sub-preprocessor', or 'frp-server') and see 'curl -s 127.0.0.1:3020/api/v1/targets' for scrape health.";
            };
            labels = {
              severity = "critical";
              service = "failures";
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
        ];
      }
    ];
  };
}
