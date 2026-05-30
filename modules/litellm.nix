{ config, ... }:

{
  services.litellm = {
    enable = true;
    host = "127.0.0.1";
    port = 27015;
    openFirewall = false;
    environmentFile = config.age.secrets.litellm-env.path;
    settings = {
      model_list = [
        {
          model_name = "research-free";
          litellm_params = {
            model = "openai/nemotron-3-super-free";
            api_base = "https://opencode.ai/zen/v1";
            api_key = "os.environ/LITELLM_ZEN_API_KEY";
            timeout = 15;
            stream_timeout = 15;
            max_retries = 0;
          };
        }
        {
          model_name = "research-free";
          litellm_params = {
            model = "openai/deepseek-v4-flash-free";
            api_base = "https://opencode.ai/zen/v1";
            api_key = "os.environ/LITELLM_ZEN_API_KEY";
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
            api_key = "os.environ/LITELLM_ZEN_API_KEY";
            timeout = 15;
            stream_timeout = 15;
            max_retries = 0;
          };
        }
        {
          model_name = "research-free";
          litellm_params = {
            model = "openai/z-ai/glm-4.5-air:free";
            api_base = "https://openrouter.ai/api/v1";
            api_key = "os.environ/LITELLM_OPENROUTER_API_KEY";
            timeout = 15;
            stream_timeout = 15;
            max_retries = 0;
          };
        }
        {
          model_name = "research-free";
          litellm_params = {
            model = "openai/meta-llama/llama-3.3-70b-instruct:free";
            api_base = "https://openrouter.ai/api/v1";
            api_key = "os.environ/LITELLM_OPENROUTER_API_KEY";
            timeout = 15;
            stream_timeout = 15;
            max_retries = 0;
          };
        }
        {
          model_name = "research-free";
          litellm_params = {
            model = "openai/openai/gpt-oss-120b:free";
            api_base = "https://openrouter.ai/api/v1";
            api_key = "os.environ/LITELLM_OPENROUTER_API_KEY";
            timeout = 15;
            stream_timeout = 15;
            max_retries = 0;
          };
        }
        {
          model_name = "research-free";
          litellm_params = {
            model = "openai/nousresearch/hermes-3-llama-3.1-405b:free";
            api_base = "https://openrouter.ai/api/v1";
            api_key = "os.environ/LITELLM_OPENROUTER_API_KEY";
            timeout = 15;
            stream_timeout = 15;
            max_retries = 0;
          };
        }
        {
          model_name = "research-free";
          litellm_params = {
            model = "openai/google/gemini-3.1-flash-lite-preview";
            api_base = "https://openrouter.ai/api/v1";
            api_key = "os.environ/LITELLM_OPENROUTER_API_KEY";
            timeout = 15;
            stream_timeout = 15;
            max_retries = 0;
          };
        }
      ];
      general_settings = {
        master_key = "os.environ/LITELLM_MASTER_KEY";
        background_health_checks = true;
        health_check_interval = 30;
        enable_health_check_routing = true;
      };
      router_settings = {
        timeout = 15;
        cooldown_time = 60;
        allowed_fails_policy = {
          AuthenticationErrorAllowedFails = 0;
          TimeoutErrorAllowedFails = 0;
          RateLimitErrorAllowedFails = 0;
        };
      };
      litellm_settings = {
        telemetry = false;
        drop_params = true;
      };
    };
  };
}
