{
  config,
  lib,
  pkgs,
  ...
}:

let
  poolSize = 4;
  poolModel = "openai/deepseek-v4.1-flash";
  poolName = "deepseek-v4.1-flash";
  poolAlias = "opencode-go-pool";
  freeModel = "openai/step-5-preview-free";
  freeName = "step-5-preview";

  sessionIdOf =
    index:
    let
      hex = builtins.hashString "sha256" "opencode-go session ${toString index}";
    in
    lib.concatStrings [
      (builtins.substring 0 8 hex)
      "-"
      (builtins.substring 8 4 hex)
      "-"
      (builtins.substring 12 4 hex)
      "-"
      (builtins.substring 16 4 hex)
      "-"
      (builtins.substring 20 12 hex)
    ];

  deployment = index: model: name: metered: {
    model_name = name;
    model_info = {
      opencode_usage_metered = metered;
    };
    litellm_params = {
      model = model;
      api_base = "https://opencode.ai/zen/go/v1";
      api_key = "os.environ/LITELLM_OPENCODE_GO_KEY_${toString (index + 1)}";
      extra_headers = {
        "x-opencode-session" = sessionIdOf (index + 1);
      };
      timeout = 900;
      stream_timeout = 180;
      max_retries = 0;
      input_cost_per_token = if metered then 3.0e-7 else 0.0;
      output_cost_per_token = if metered then 1.2e-6 else 0.0;
      cache_read_input_token_cost = if metered then 6.0e-9 else 0.0;
    };
  };

  configYaml = (pkgs.formats.yaml { }).generate "litellm-config.yaml" {
    model_list =
      lib.imap0 (index: _: deployment index poolModel poolName true) (lib.range 1 poolSize)
      ++ lib.imap0 (index: _: deployment index freeModel freeName false) (lib.range 1 poolSize);
    general_settings = {
      master_key = "os.environ/LITELLM_MASTER_KEY";
      database_url = "os.environ/DATABASE_URL";
      enable_health_check_routing = true;
    };
    router_settings = {
      timeout = 900;
      cooldown_time = 600;
      routing_strategy = "simple-shuffle";
      enable_weighted_failover = true;
      num_retries = 3;
      model_group_alias = {
        ${poolAlias} = poolName;
      };
    };
    litellm_settings = {
      telemetry = false;
      drop_params = true;
    };
  };

  dbEnv = config.age.secrets.litellm-db-env.path;
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
        LITELLM_WORKER_STARTUP_HOOKS = "opencode_go_usage:install_usage_route";
      };
      volumes = [
        "${configYaml}:/app/config.yaml:ro"
        "${./opencode-usage.py}:/app/opencode_go_usage.py:ro"
      ];
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
}
