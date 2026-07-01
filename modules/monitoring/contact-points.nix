{ config, ... }:

# Shared Grafana notification channels. Every alert rule under
# modules/monitoring/ routes to a contact point defined here via its
# `notification_settings.receiver`, so the channel (and its secret) is declared
# once and never duplicated per service.
{
  # Telegram bot token + chat id as a single agenix KEY=value env file
  # (TELEGRAM_BOT_TOKEN=... / CHAT_ID=...), mirroring modules/frp.nix's frp.age.
  # owner=root because it is consumed via systemd EnvironmentFile below, which
  # systemd reads as root before the grafana service drops privileges (same
  # pattern as modules/zerossl.nix) — the grafana process never opens the file.
  age.secrets.grafana-telegram = {
    file = ../../secrets/grafana-telegram.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  # Inject the secret's KEY=value pairs into grafana's process environment;
  # services.grafana has no native environmentFile option, so wire the unit
  # directly (as in modules/zerossl.nix). Grafana then expands the $__env{...}
  # references in the contact point below at provisioning-load time.
  systemd.services.grafana.serviceConfig.EnvironmentFile = [
    config.age.secrets.grafana-telegram.path
  ];

  services.grafana.provision.alerting.contactPoints.settings = {
    apiVersion = 1;
    contactPoints = [
      {
        orgId = 1;
        name = "telegram";
        receivers = [
          {
            uid = "telegram";
            type = "telegram";
            settings = {
              bottoken = "$__env{TELEGRAM_BOT_TOKEN}";
              chatid = "$__env{CHAT_ID}";
              message = ''
                {{ range .Alerts }}{{ .Annotations.summary }}
                {{ end }}'';
            };
          }
        ];
      }
    ];
  };
}
