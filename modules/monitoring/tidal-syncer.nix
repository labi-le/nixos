{ ... }:

# Alert 1 (reauth): the tidal-syncer daemon's TIDAL session died and needs an interactive
# `tidal-syncer login`. The daemon never self-reauths; on a revoked or expired
# refresh token it logs at ERROR every cycle, records the failure and keeps
# polling with the unit still `active` -- so neither systemd nor a healthcheck
# will ever tell you about it.
#
# This used to be a Loki log alert on the docker container's stdout. That died
# with the move to a native systemd service (../tidal-syncer.nix): Alloy only
# ships docker containers (job="docker") plus one journal unit, so the query
# matched nothing, and `noDataState = "OK"` turned it into a permanently green
# alert -- the worst possible failure for a silent condition.
#
# The condition is a first-class metric instead. internal/metrics pre-initialises
# every error class to 0 at startup, so a healthy daemon publishes a real 0-valued
# series rather than no series at all; this rule therefore cannot rot into
# NoData-as-OK the way the log query did.
#
# Alert 2 (down): the daemon stopped exporting metrics altogether. The reauth
# rule deliberately reads a missing metric as OK -- with the series gone there
# is nothing left to say about the session -- so on its own it would be exactly
# as silent about a dead daemon as the old Loki query was. `up` is Prometheus'
# own scrape result and exists for as long as the scrape job does.
#
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
              # A: re-auth failures counted over the last 26h. The lookback is
              # deliberately long: in time_window mode (02:00-06:00, min=max=4h)
              # the daemon runs roughly one cycle per day, so a 5m or 15m range
              # would sit at zero between windows and miss the event entirely.
              # 26h covers one full window plus slack, and makes the alert
              # self-resolve about a day after the last failure -- i.e. once a
              # successful login stops the counter from growing.
              {
                refId = "A";
                relativeTimeRange = {
                  from = 93600;
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
                  expr = ''increase(tidal_syncer_sync_errors_total{class="reauth"}[26h])'';
                  instant = true;
                  range = false;
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
              # C: fire when at least one re-auth failure was recorded (> 0).
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
            # NoData here means the metric itself is gone -- the daemon is down or
            # unscraped, which is a different problem than a dead session and is
            # covered by the sibling `tidal-syncer-down` rule below. Keep it quiet
            # so a rebuild restarting the unit does not page twice.
            noDataState = "OK";
            execErrState = "Error";
            for = "0m";
            annotations = {
              summary = "TIDAL session expired on server: run 'tidal-syncer-login' (or 'systemctl start tidal-syncer-login' and watch 'journalctl -fu tidal-syncer-login' for the verification URL) to re-authorize.";
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
          {
            uid = "tidal-syncer-down";
            title = "tidal-syncer is not exporting metrics";
            condition = "C";
            data = [
              # A: Prometheus' own scrape result for the daemon's metrics
              # endpoint -- 1 while the scrape succeeds, 0 when it fails, and
              # absent only if the scrape job itself vanished from the config.
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
                  expr = ''up{job="tidal-syncer"}'';
                  instant = true;
                  range = false;
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
              # C: fire while the scrape is failing (up < 1).
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
            # A missing `up` means the scrape job was dropped from Prometheus, so
            # nothing is watching the daemon at all -- as broken as a dead target
            # and not something to stay quiet about. `for` below absorbs the gap a
            # rebuild leaves while the unit restarts.
            noDataState = "Alerting";
            execErrState = "Error";
            for = "10m";
            annotations = {
              summary = "tidal-syncer is not exporting metrics: check 'systemctl status tidal-syncer' and 'journalctl -u tidal-syncer -n 50' on the server.";
            };
            labels = {
              severity = "warning";
              service = "tidal-syncer";
            };
            isPaused = false;
            notification_settings = {
              receiver = "telegram";
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
