{
  config,
  lib,
  pkgs,
  ...
}:

let
  catalog = import ./models { inherit lib; };

  configYaml = (pkgs.formats.yaml { }).generate "litellm-config.yaml" (
    import ./config.nix { inherit catalog; }
  );

  dbEnv = config.age.secrets.litellm-db-env.path;

  zenGroupsJson = pkgs.writeText "litellm-zen-groups.json" (builtins.toJSON catalog.zenGroupNames);
in

{
  age.secrets.opencode-go-pool-env = {
    file = ../../secrets/opencode-go-pool-env.age;
    mode = "0400";
  };

  age.secrets.litellm-db-env = {
    file = ../../secrets/litellm-db-env.age;
    mode = "0400";
  };

  environment.systemPackages = [ (pkgs.callPackage ./litellm-key.nix { }) ];

  systemd.tmpfiles.rules = [
    "d /var/lib/litellm-db 0700 999 999 -"
    "d /var/lib/litellm-chatgpt 0700 0 0 -"
    "d /var/lib/litellm-price-sync 0700 0 0 -"
  ];

  virtualisation.oci-containers.backend = "docker";
  virtualisation.oci-containers.containers = {
    litellm-db = {
      image = "postgres:17";
      environment = {
        POSTGRES_USER = "litellm";
        POSTGRES_DB = "litellm";
      };
      environmentFiles = [ dbEnv ];
      volumes = [ "/var/lib/litellm-db:/var/lib/postgresql/data" ];
      networks = [ "litellm" ];
      log-driver = "journald";
    };
    litellm = {
      image = "ghcr.io/berriai/litellm:main-stable";
      environmentFiles = [
        config.age.secrets.litellm-env.path
        config.age.secrets.opencode-go-pool-env.path
        dbEnv
      ];
      environment = {
        PYTHONPATH = "/app";
        LITELLM_WORKER_STARTUP_HOOKS = "opencode_go_usage:install_usage_route,opencode_session:install_session_forwarder,reasoning_params:install_reasoning_effort_params";
      };
      volumes = [
        "${configYaml}:/app/config.yaml:ro"
        "${./opencode-usage.py}:/app/opencode_go_usage.py:ro"
        "${./opencode-session.py}:/app/opencode_session.py:ro"
        "${./reasoning-params.py}:/app/reasoning_params.py:ro"
        "/var/lib/litellm-chatgpt:/root/.config/litellm/chatgpt"
      ];
      extraOptions = [ "--dns=192.168.1.1" ];
      ports = [ "127.0.0.1:27015:4000" ];
      networks = [ "litellm" ];
      dependsOn = [ "litellm-db" ];
      log-driver = "journald";
      cmd = [
        "--config"
        "/app/config.yaml"
        "--port"
        "4000"
      ];
    };
  };

  systemd.services."docker-network-litellm" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = "docker network inspect litellm >/dev/null 2>&1 || docker network create litellm";
    wantedBy = [ "multi-user.target" ];
  };

  systemd.services."docker-litellm-db" = {
    after = [ "docker-network-litellm.service" ];
    requires = [ "docker-network-litellm.service" ];
  };

  systemd.services."docker-litellm" = {
    after = [ "docker-network-litellm.service" ];
    requires = [ "docker-network-litellm.service" ];
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartSec = lib.mkOverride 90 "5s";
    };
  };

  systemd.services.litellm-price-sync = {
    description = "Sync the OpenCode Go price table into the litellm catalog";
    after = [ "docker-litellm.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [
      pkgs.coreutils
      pkgs.docker
      pkgs.git
      pkgs.util-linux
    ];
    serviceConfig = {
      Type = "oneshot";
      MemoryHigh = "8G";
      MemoryMax = "10G";
      MemorySwapMax = 0;
    };
    script = ''
      exec ${pkgs.python3}/bin/python3 ${./sync-prices.py} \
        --repo /home/labile/nix \
        --groups ${zenGroupsJson} \
        --as-user labile \
        --apply --commit --push --rebuild --verify --metric
    '';
  };

  systemd.timers.litellm-price-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      RandomizedDelaySec = "30min";
      Persistent = true;
    };
  };

  systemd.services.litellm-limits-exporter = {
    description = "Publish provider-side API limits (OpenCode Go pool, ChatGPT Codex) as Prometheus metrics";
    after = [ "docker-litellm.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      exec ${pkgs.python3}/bin/python3 ${./limits-exporter.py}
    '';
  };

  systemd.timers.litellm-limits-exporter = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/5";
      RandomizedDelaySec = "30s";
    };
  };
}
