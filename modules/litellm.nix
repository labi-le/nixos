{
  config,
  lib,
  pkgs,
  ...
}:

let
  poolSize = 4;
  poolModel = "openai/deepseek-v4.1-flash";
  poolAgent = "jcode/0.89.3";

  usagePlugin = pkgs.runCommand "litellm-opencode-usage" { } ''
    mkdir -p $out
    cp ${../pkgs/litellm-opencode-usage.py} $out/opencode_go_usage.py
  '';

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
in

{
  age.secrets.opencode-go-pool-env = {
    file = ../secrets/opencode-go-pool-env.age;
    mode = "0400";
  };

  systemd.services.litellm.serviceConfig.EnvironmentFile =
    lib.mkAfter [ config.age.secrets.opencode-go-pool-env.path ];
  services.litellm = {
    enable = true;
    host = "127.0.0.1";
    port = 27015;
    openFirewall = true;
    environmentFile = config.age.secrets.litellm-env.path;
    settings = {
      model_list = lib.imap0 (index: _: {
        model_name = "opencode-go-pool";
        litellm_params = {
          model = poolModel;
          api_base = "https://opencode.ai/zen/go/v1";
          api_key = "os.environ/LITELLM_OPENCODE_GO_KEY_${toString (index + 1)}";
          extra_headers = {
            "x-opencode-session" = sessionIdOf (index + 1);
            "user-agent" = poolAgent;
          };
          timeout = 900;
          stream_timeout = 180;
          max_retries = 0;
        };
      }) (lib.range 1 poolSize);
      general_settings = {
        master_key = "os.environ/LITELLM_MASTER_KEY";
        background_health_checks = true;
        health_check_interval = 120;
        enable_health_check_routing = true;
      };
      router_settings = {
        timeout = 900;
        cooldown_time = 600;
        routing_strategy = "simple-shuffle";
        enable_weighted_failover = true;
        num_retries = 3;
      };
      litellm_settings = {
        telemetry = false;
        drop_params = true;
        callbacks = [ "${usagePlugin}/opencode_go_usage.opencode_go_usage_sync" ];
      };
    };
  };
}
