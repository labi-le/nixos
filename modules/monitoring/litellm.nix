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
            uid = "litellm-codex-token-invalid";
            title = "The ChatGPT token behind the litellm Codex groups is dead";
            expr = "litellm_codex_token_valid == 0";
            for = "5m";
            severity = "critical";
            summary = "Every Codex group answers 401 and a refresh did not help; the account needs a device login.";
            command = "journalctl -u litellm-chatgpt-token -n 40\ndocker logs --since 15m litellm | grep -i 'token has expired'";
          })
        ];
      }
    ];
    deleteRules = [
      {
        orgId = 1;
        uid = "litellm-free-probe-failed";
      }
      {
        orgId = 1;
        uid = "litellm-free-probe-stale";
      }
    ];
  };
}
