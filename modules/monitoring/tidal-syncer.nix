{ ... }:

# Alert: the tidal-syncer daemon's TIDAL session died and needs an interactive
# `tidal-syncer login`. The daemon never self-reauths; on a revoked/expired
# refresh token it logs, at ERROR, the stable line "re-authentication required:
# run 'tidal-syncer login' to re-authorize" every poll tick and keeps running
# with a green healthcheck — so a log alert is the only reliable signal.
#
# Nothing to collect here: Alloy (see ../grafana.nix) already tails every docker
# container's stdout into Loki labelled container=<docker name>. The daemon runs
# under docker-compose, so its real label is "tidal-syncer-tidal-syncer-1"
# (<project>-<service>-<idx>) — hence the container=~"tidal-syncer.*" match below.
# Routes to the shared "telegram" contact point (./contact-points.nix).
{
  services.grafana.provision.alerting.rules.settings = {
    apiVersion = 1;
    groups = [
      {
        orgId = 1;
        name = "tidal-syncer";
        # File provisioning creates this folder if it does not exist.
        folder = "tidal-syncer";
        interval = "1m";
        rules = [
          {
            uid = "tidal-syncer-reauth";
            title = "TIDAL session expired - re-login required";
            condition = "C";
            data = [
              # A: how many "re-authentication required" lines the tidal-syncer
              # container logged in the last 5m. When healthy there are zero
              # matching lines, so Loki returns no series (NoData), which
              # noDataState maps to OK below.
              {
                refId = "A";
                relativeTimeRange = {
                  from = 600;
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
                  expr = ''count_over_time({container=~"tidal-syncer.*", job="docker"} |= `re-authentication required` [5m])'';
                  queryType = "instant";
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                };
              }
              # B: collapse the series to its last value.
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
              # C: fire when at least one such line was seen (> 0).
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
            # No matching log line -> Loki returns no series -> treat as OK
            # (the healthy steady state), not as a firing/again-noisy alert.
            noDataState = "OK";
            execErrState = "Error";
            for = "0m";
            annotations = {
              summary = "TIDAL session expired on server: run 'tidal-syncer login' (docker compose run --rm tidal-syncer login) to re-authorize.";
            };
            labels = {
              severity = "warning";
              service = "tidal-syncer";
            };
            isPaused = false;
            # Route straight to the shared Telegram contact point without
            # touching Grafana's root notification policy.
            notification_settings = {
              receiver = "telegram";
              group_by = [ "alertname" ];
              group_wait = "30s";
              group_interval = "5m";
              # Re-nudge every 6h while the session stays dead.
              repeat_interval = "6h";
            };
          }
        ];
      }
    ];
  };
}
