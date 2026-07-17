{ ... }:

# Grafana monitoring aggregator. Merges into the services.grafana defined in
# ../grafana.nix (Prometheus/Loki/Alloy live there).
#
# Layout: shared notification channels live in ./contact-points.nix; every
# monitored service gets its own ./<service>.nix holding only that service's
# alert rule(s). To monitor another service: add ./<service>.nix (with its own
# services.grafana.provision.alerting.rules) and list it below — it reuses the
# shared contact points, so nothing here becomes a dumping ground.
{
  imports = [
    ./contact-points.nix
    ./tidal-syncer.nix
    ./sub-preprocessor.nix
  ];
}
