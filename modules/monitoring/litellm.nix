{ ... }:

let
  rule =
    {
      uid,
      title,
      expr,
      for ? "0s",
      severity ? "warning",
      receiver ? "telegram-admin",
      repeat_interval ? "1h",
      summary,
      command,
    }:
    {
      inherit
        uid
        title
        for
        ;
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
            inherit expr;
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
      annotations = {
        inherit summary;
        inherit command;
      };
      labels = {
        inherit severity;
        service = "litellm";
      };
      isPaused = false;
      notification_settings = {
        inherit receiver;
        group_by = [ "alertname" ];
        group_wait = "30s";
        group_interval = "5m";
        inherit repeat_interval;
      };
    };
in
{
  services.grafana.provision.alerting.rules.settings = {
    apiVersion = 1;
    groups = [
      {
        orgId = 1;
        name = "litellm";
        folder = "litellm";
        interval = "1m";
        rules = [
          (rule {
            uid = "litellm-price-sync-failed";
            title = "The litellm price sync refused to apply the OpenCode Go table";
            expr = "litellm_price_sync_anomaly > 0";
            for = "5m";
            severity = "critical";
            summary = "Zen prices are no longer syncing from the Go table; the gateway still bills the last applied rates.";
            command = "journalctl -u litellm-price-sync -n 80\ncat /var/lib/litellm-price-sync/state.json";
          })
          (rule {
            uid = "litellm-price-changed";
            title = "Zen prices changed in the OpenCode Go table";
            expr = "litellm_price_sync_change > 0";
            receiver = "telegram-admin-events";
            repeat_interval = "24h";
            summary = "The price sync applied a new rate; budgets and spend now follow it.";
            command = "git -C /home/labile/nix log -1 --stat modules/litellm/models/prices.json";
          })
          (rule {
            uid = "litellm-price-sync-stale";
            title = "The litellm price sync has not succeeded for three days";
            expr = "time() - litellm_price_sync_last_success_timestamp_seconds > 259200";
            for = "1h";
            severity = "critical";
            summary = "Nothing has refreshed the Zen prices for three days; the timer or the service is down.";
            command = "systemctl status litellm-price-sync.timer litellm-price-sync.service";
          })
          (rule {
            uid = "litellm-free-probe-failed";
            title = "A Zen free group stopped accepting requests";
            expr = "litellm_free_probe_ok == 0";
            for = "6m";
            severity = "critical";
            summary = "Zen free {{ $labels.model }} stopped accepting requests: {{ $labels.state }}. The zero-token probe no longer reaches the model layer through the gateway.{{ if eq $labels.state \"gate\" }} That is the free tier refusing the fingerprint again, so the client footprint moved, not the network or the account pool.{{ else if eq $labels.state \"deprecated\" }} That is the upstream withdrawing the model id, so the group has to be replaced or removed.{{ else if eq $labels.state \"quota\" }} That is the free allowance or the rate limit being exhausted.{{ else if eq $labels.state \"protocol\" }} That is one route no longer reaching the model: the upstream dropped a protocol, the chat-completions bridge is off, or the model moved to the other route.{{ else if eq $labels.state \"http\" }} That is the gateway answering something else, usually a missing deployment or a changed error shape.{{ end }}";
            command = "journalctl -u litellm-free-probe -n 60 --no-pager\ncat /var/lib/litellm-free-probe/state.json";
          })
          (rule {
            uid = "litellm-free-probe-stale";
            title = "The Zen free probe stopped running";
            expr = "time() - litellm_free_probe_run_timestamp_seconds > 7200";
            for = "1h";
            severity = "critical";
            summary = "The probe that watches the Zen free groups has not run for two hours, so a broken group would now go unnoticed; the timer or the unit is down.";
            command = "systemctl status litellm-free-probe.timer litellm-free-probe.service\njournalctl -u litellm-free-probe -n 40 --no-pager";
          })
        ];
      }
    ];
  };
}
