{ config, lib, ... }:

let
  poolSize = 4;
  poolModel = "openai/deepseek-v4.1-flash";
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
      model_list = [
        {
          model_name = "research-free";
          litellm_params = {
            model = "openai/deepseek-v4-flash-free";
            api_base = "https://opencode.ai/zen/v1";
            api_key = "os.environ/LITELLM_OPENCODE_ZEN_API_KEY";
            timeout = 15;
            stream_timeout = 15;
            max_retries = 0;
          };
        }
        {
          model_name = "research-free";
          litellm_params = {
            model = "openai/mimo-v2.5-free";
            api_base = "https://opencode.ai/zen/v1";
            api_key = "os.environ/LITELLM_OPENCODE_ZEN_API_KEY";
            timeout = 15;
            stream_timeout = 15;
            max_retries = 0;
          };
        }
        {
          model_name = "research-free";
          litellm_params = {
            model = "openai/qwen3.6-plus-free";
            api_base = "https://opencode.ai/zen/v1";
            api_key = "os.environ/LITELLM_OPENCODE_ZEN_API_KEY";
            timeout = 15;
            stream_timeout = 15;
            max_retries = 0;
          };
        }
      ]
      ++ lib.imap0 (index: _: {
        model_name = "opencode-go-pool";
        litellm_params = {
          model = poolModel;
          api_base = "https://opencode.ai/zen/go/v1";
          api_key = "os.environ/LITELLM_OPENCODE_GO_KEY_${toString (index + 1)}";
          timeout = 900;
          stream_timeout = 180;
          max_retries = 0;
        };
      }) (lib.range 1 poolSize);
      general_settings = {
        master_key = "os.environ/LITELLM_MASTER_KEY";
        background_health_checks = false;
        enable_health_check_routing = false;
      };
      router_settings = {
        timeout = 15;
        cooldown_time = 60;
        disable_cooldowns = true;
        routing_strategy = "simple-shuffle";
        enable_weighted_failover = true;
        num_retries = 3;
        allowed_fails_policy = {
          AuthenticationErrorAllowedFails = 0;
          TimeoutErrorAllowedFails = 1;
          RateLimitErrorAllowedFails = 1;
          InternalServerErrorAllowedFails = 1;
        };
      };
      litellm_settings = {
        telemetry = false;
        drop_params = true;
      };
    };
  };
}
