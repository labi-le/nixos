{ config, ... }:
{
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

    };
    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://127.0.0.1:${toString config.services.prometheus.port}";
        }
        {
          name = "Loki";
          type = "loki";
          access = "proxy";
          url = "http://127.0.0.1:3100";
        }
      ];
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

  systemd.services.promtail = {
    serviceConfig = {
      StateDirectory = "promtail";
      ReadWritePaths = [
        "/var/lib/promtail"
        "/var/run/docker.sock"
        "/var/lib/docker/containers"
      ];
      SupplementaryGroups = [ "docker" ];
    };
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
  };
  services.promtail = {
    enable = true;
    configuration = {
      server = {
        http_listen_port = 9080;
        grpc_listen_port = 0;
      };

      positions = {
        filename = "/var/lib/promtail/positions.yaml";
      };

      clients = [
        {
          url = "http://localhost:${toString config.services.loki.configuration.server.http_listen_port}/loki/api/v1/push";
          batchwait = "1s";
          batchsize = 102400;
          timeout = "10s";
        }
      ];

      scrape_configs = [
        {
          job_name = "nginx";
          static_configs = [
            {
              # targets = [ "localhost" ];
              labels = {
                job = "nginx";
                __path__ = "/var/log/nginx/*.log";
              };
            }
          ];
          pipeline_stages = [
            {
              regex = {
                expression = ''^(?P<ip>\S+) \S+ \S+ \[(?P<timestamp>[^\]]+)\] "(?P<method>\S+) (?P<path>\S+) \S+" (?P<status>\d+) (?P<size>\d+) "(?P<referer>[^"]*)" "(?P<ua>[^"]*)"'';
              };
            }
            {
              labels = {
                method = null;
                status = null;
              };
            }
          ];
        }
        {
          job_name = "docker";
          docker_sd_configs = [
            {
              host = "unix:///var/run/docker.sock";
              refresh_interval = "2s";
            }
          ];
          relabel_configs = [
            {
              source_labels = [ "__meta_docker_container_name" ];
              regex = "/(.*)";
              target_label = "container";
            }
            {
              source_labels = [ "__meta_docker_container_log_stream" ];
              target_label = "logstream";
            }
          ];
        }
      ];
    };
  };
}
