{ config, ... }:

{
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
            model = "deepseek/deepseek-v4-flash";
            api_base = "https://api.aigate.shop/v1";
            api_key = "os.environ/LITELLM_AIGATE_API_KEY";
            timeout = 15;
            stream_timeout = 15;
            max_retries = 0;
          };
        }
        {
          model_name = "research-free";
          litellm_params = {
            model = "xiaomi/mimo-v2.5";
            api_base = "https://api.aigate.shop/v1";
            api_key = "os.environ/LITELLM_AIGATE_API_KEY";
            timeout = 15;
            stream_timeout = 15;
            max_retries = 0;
          };
        }
        {
          model_name = "research-free";
          litellm_params = {
            model = "deepseek-v4-flash-free";
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
            model = "mimo-v2.5-free";
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
            model = "qwen3.6-plus-free";
            api_base = "https://opencode.ai/zen/v1";
            api_key = "os.environ/LITELLM_OPENCODE_ZEN_API_KEY";
            timeout = 15;
            stream_timeout = 15;
            max_retries = 0;
          };
        }
      ];
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
