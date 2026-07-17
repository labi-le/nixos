{ ... }:

# sub-preprocessor monitoring. Prometheus/Loki/Grafana themselves live in
# ../grafana.nix; this module only appends this service's scrape job and
# provisions its dashboard.
#
# The stable worker exposes an internal Prometheus endpoint that docker-compose
# publishes on 127.0.0.1:9091 (loopback-only, so it is scrapable by the host
# Prometheus but not reachable off-box). The dashboard picks the Prometheus
# datasource through a template variable, so it needs no fixed datasource uid.
{
  services.prometheus.scrapeConfigs = [
    {
      job_name = "sub-preprocessor";
      static_configs = [ { targets = [ "127.0.0.1:9091" ]; } ];
    }
  ];

  services.grafana.provision.dashboards.settings = {
    apiVersion = 1;
    providers = [
      {
        name = "sub-preprocessor";
        type = "file";
        disableDeletion = true;
        options = {
          path = ./dashboards;
          foldersFromFilesStructure = false;
        };
      }
    ];
  };
}
