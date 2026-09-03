{ ... }:

# Alerts on frp-server tunnel drops: a client losing its tunnel logs a burst of
# EOF/stream-closed lines. Requires the Alloy frp journal source in ../grafana.nix
# to ship job="frp" logs to Loki; without it this query matches nothing.
#
# noDataState = "OK": no matching lines is the healthy state, so an empty result
# must resolve green instead of paging on every quiet minute.
#
# Routes to the shared "telegram" contact point (./contact-points.nix).
{
  services.grafana.provision.alerting.rules.settings = {
    apiVersion = 1;
    groups = [
      {
        orgId = 1;
        name = "frp";
        folder = "frp";
        interval = "1m";
        rules = [
          {
            uid = "frp-conn-loss";
            title = "frp tunnel connection lost";
            condition = "C";
            data = [
              {
                refId = "A";
                relativeTimeRange = {
                  from = 300;
                  to = 0;
                };
                datasourceUid = "loki";
                model = {
                  refId = "A";
                  datasource = {
                    type = "loki";
                    uid = "loki";
                  };
                  editorMode = "code";
                  expr = ''count_over_time({job="frp"} |~ "read from workConn for udp error: EOF|failed to send message to work connection from pool: stream closed|failed to get work connection: control is closed" | regexp "(?P<message>[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}[.][0-9]+ .*)" [5m])'';
                  queryType = "range";
                  instant = false;
                  range = true;
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
            for = "0m";
            annotations = {
              summary = "frp issues";
            };
            labels = {
              severity = "warning";
              service = "frp";
            };
            isPaused = false;
            notification_settings = {
              receiver = "telegram-frp";
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
