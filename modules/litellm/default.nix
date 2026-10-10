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
