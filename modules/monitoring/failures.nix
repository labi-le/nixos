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
              summary = "{{ $labels.name }} failed";
              command = "systemctl status {{ $labels.name }}\njournalctl -u {{ $labels.name }} -n 50";
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
              summary = "{{ $labels.name }} restarted more than 5 times in 15m";
              command = "systemctl status {{ $labels.name }}\njournalctl -u {{ $labels.name }} -n 100";
            };
            labels = {
              severity = "critical";
              service = "failures";
            };
            isPaused = false;
            notification_settings = {
              receiver = "telegram-admin-events";
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
              summary = "{{ $labels.name }} restarted more than 3 times in 15m";
              command = "docker inspect {{ $labels.name }}\ndocker logs --tail 100 {{ $labels.name }}";
            };
            labels = {
              severity = "critical";
              service = "failures";
            };
            isPaused = false;
            notification_settings = {
              receiver = "telegram-admin-events";
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
              summary = "{{ $labels.name }} is not running";
              command = "docker ps -a --filter name={{ $labels.name }}\ndocker logs --tail 100 {{ $labels.name }}";
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
              summary = "{{ $labels.name }} failed its health check";
              command = "docker inspect {{ $labels.name }} | jq .State.Health";
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
              summary = "no metric update for more than 3m — container checks are blind";
              command = "systemctl status docker-container-state-exporter.timer\njournalctl -u docker-container-state-exporter -n 50";
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
              summary = "a process was killed in the last 5m";
              command = "journalctl -k --grep=\"Out of memory\"\ndmesg -T | grep -i \"killed process\"";
            };
            labels = {
              severity = "critical";
              service = "failures";
            };
            isPaused = false;
            notification_settings = {
              receiver = "telegram-admin-events";
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
              summary = "{{ $labels.job }} target {{ $labels.instance }} is down";
              command = "curl -s 127.0.0.1:3020/api/v1/targets | jq -r '.data.activeTargets[] | select(.health != \"up\") | .scrapeUrl, .lastError'";
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
