{ config, ... }:

# Shared Grafana notification channels. Every alert rule under
# modules/monitoring/ routes to a contact point defined here via its
# `notification_settings.receiver`, so the channel (and its secret) is declared
# once and never duplicated per service.
{
  # Telegram bot token as an agenix KEY=value env file (TELEGRAM_BOT_TOKEN=...),
  # mirroring modules/frp.nix's frp.age. owner=root because it is consumed via
  # the systemd EnvironmentFile below, which systemd reads as root before the
  # grafana service drops privileges (same pattern as modules/zerossl.nix) — the
  # grafana process never opens the file.
  #
  # NOTE: only the bot token is injected from the secret. The chat id is NOT:
  # Grafana 13's $__env{} expansion coerces a numeric-looking value into a JSON
  # number, but telegram's `chatid` is a string field, so every env form fails
  # provisioning with `cannot unmarshal number into ... chatid of type string`
  # (source quoting and !!str do not help — verified empirically against
  # grafana 13.0.3). A chat id is not a secret (useless without the bot token),
  # so it is hardcoded below; a leftover CHAT_ID= line in the age file is ignored.
  age.secrets.grafana-telegram = {
    file = ../../secrets/grafana-telegram.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  # Inject the secret's KEY=value pairs into grafana's process environment;
  # services.grafana has no native environmentFile option, so wire the unit
  # directly (as in modules/zerossl.nix). Grafana then expands the
  # $__env{TELEGRAM_BOT_TOKEN} reference in the contact point below at
  # provisioning-load time.
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
              # Hardcoded (not $__env) — see the NOTE above: grafana cannot
              # inject a numeric chat id from an env var as a string.
              chatid = "395448554";
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
