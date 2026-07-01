{ config, ... }:

{
  age.secrets.grafana = {
    file = ../secrets/grafana.age;
    owner = "grafana";
    group = "grafana";
    mode = "0400";
  };

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = 8008;
        serve_from_sub_path = true;
        domain = "logs.labile.cc";
      };
      analytics.reporting_enabled = false;
      security.secret_key = config.age.secrets.grafana.path;

    };
    provision = {
      enable = true;
      datasources.settings = {
        # Grafana 13's datasource provisioner cannot CHANGE the uid of an
        # already-provisioned datasource. Once Loki has been provisioned with
        # its original random uid, adding the fixed `uid = "loki"` below makes
        # provisioning abort with `Datasource provisioning error: data source
        # not found`, crashing grafana on every boot (start-limit-hit). Deleting
        # Loki first lets it be recreated with the stable uid; this is idempotent
        # (delete is a no-op when absent) and self-heals any future uid change.
        deleteDatasources = [
          {
            name = "Loki";
            orgId = 1;
          }
        ];
        datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://127.0.0.1:${toString config.services.prometheus.port}";
          }
          {
            name = "Loki";
            # Stable uid so provisioned alert rules can target this datasource by
            # uid (see modules/monitoring/tidal-syncer.nix). Without it Grafana
            # assigns a random uid the rules cannot reference.
            uid = "loki";
            type = "loki";
            access = "proxy";
            url = "http://127.0.0.1:3100";
          }
        ];
      };
    };
  };

  services.prometheus = {
    port = 3020;
    enable = true;

    exporters = {
      node = {
        port = 3021;
        enabledCollectors = [
          "systemd"
          "cpu"
          "meminfo"
          "netdev"
          "diskstats"
          "filesystem"
          "loadavg"
          "stat"
          "uname"
          "vmstat"
          "time"
        ];
        enable = true;
      };
      nginx = {
        enable = true;
      };
    };

    scrapeConfigs = [
      {
        job_name = "nodes";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
          }
        ];
      }
      {
        job_name = "nginx";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.nginx.port}" ];
          }
        ];
      }
      {
        job_name = "telegraf";
        static_configs = [
          {
            targets = [ "127.0.0.1:9273" ];
          }
        ];
      }
    ];
  };

  services.loki = {
    enable = true;
    configuration = {
      auth_enabled = false;

      server = {
        http_listen_port = 3100;
      };

      common = {
        path_prefix = "/var/lib/loki";
        storage = {
          filesystem = {
            chunks_directory = "/var/lib/loki/chunks";
            rules_directory = "/var/lib/loki/rules";
          };
        };
        replication_factor = 1;
        ring = {
          instance_addr = "127.0.0.1";
          kvstore = {
            store = "inmemory";
          };
        };
      };

      schema_config = {
        configs = [
          {
            from = "2024-03-23";
            store = "tsdb";
            object_store = "filesystem";
            schema = "v13";
            index = {
              prefix = "tsdb_";
              period = "24h";
            };
          }
        ];
      };

      query_scheduler = {
        max_outstanding_requests_per_tenant = 2048;
      };

      limits_config = {
        ingestion_rate_mb = 32;
        ingestion_burst_size_mb = 64;
        max_streams_per_user = 10000;
      };
    };
  };

  # Grafana Alloy ships logs into Loki so they are viewable/greppable in Grafana.
  # (services.promtail was removed in NixOS 26.05 — Alloy is the supported replacement.)
  # Three sources feed a single loki.write sink:
  #   - nginx/angie access+error files    -> job="nginx"   (see modules/nginx.nix)
  #   - docker container stdout/stderr    -> job="docker"  (label container=<name>)
  #   - fail2ban (logs to SYSLOG=journal) -> job="fail2ban"
  services.alloy.enable = true;

  environment.etc."alloy/config.alloy".text = ''
    // nginx/angie writes /var/log/nginx/{access,error}.log (logrotate disabled, so the
    // files grow unbounded — tail_from_end avoids re-ingesting the whole backlog on start).
    local.file_match "nginx" {
      path_targets = [
        { __path__ = "/var/log/nginx/access.log", job = "nginx", logtype = "access" },
        { __path__ = "/var/log/nginx/error.log",  job = "nginx", logtype = "error"  },
      ]
    }

    loki.source.file "nginx" {
      targets       = local.file_match.nginx.targets
      forward_to    = [loki.write.local.receiver]
      tail_from_end = true
    }

    // Docker: discover running containers via the daemon socket and read their logs
    // through the Docker API (works regardless of a container's log-driver).
    discovery.docker "containers" {
      host = "unix:///var/run/docker.sock"
    }

    // Expose the container name (strip Docker's leading "/") as the `container` label.
    discovery.relabel "containers" {
      targets = discovery.docker.containers.targets

      rule {
        source_labels = ["__meta_docker_container_name"]
        regex         = "/(.*)"
        target_label  = "container"
      }
    }

    loki.source.docker "containers" {
      host       = "unix:///var/run/docker.sock"
      targets    = discovery.relabel.containers.output
      labels     = { job = "docker" }
      forward_to = [loki.write.local.receiver]
    }

    // fail2ban logs to SYSLOG, which under systemd lands in the journal tagged with
    // its unit; read just that unit so bans/unbans are greppable.
    loki.source.journal "fail2ban" {
      matches    = "_SYSTEMD_UNIT=fail2ban.service"
      labels     = { job = "fail2ban" }
      forward_to = [loki.write.local.receiver]
    }

    loki.write "local" {
      endpoint {
        url = "http://127.0.0.1:3100/loki/api/v1/push"
      }
    }
  '';

  # Alloy runs as a systemd DynamicUser, so it must join the group owning each source or
  # it silently reads nothing (no error, zero log lines). NixOS concatenates this with the
  # module's default ["systemd-journal"], yielding ["systemd-journal" "nginx" "docker"]:
  #   systemd-journal -> read the journal (fail2ban)
  #   nginx           -> read 0640 nginx:nginx files in the 0750 nginx:nginx log dir
  #   docker          -> read /var/run/docker.sock
  systemd.services.alloy.serviceConfig.SupplementaryGroups = [ "nginx" "docker" ];
}
