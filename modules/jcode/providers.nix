{ config, lib }:

let
  poolCatalog = import ../litellm/models { inherit lib; };

  poolModel =
    group:
    {
      id = group.name;
      reasoning = group.reasoningEffortLevels != [ ];
      context_window = group.maxInputTokens;
      input = [ "text" ] ++ lib.optional group.supportsVision "image";
    };

  poolModels = map poolModel poolCatalog.groups;

  baseProviders = {
    byesu = {
      type = "openai-compatible";
      base_url = "https://byesu.com/v1";
      api_key_env = "BYESU_API_KEY";
      env_file = "byesu.env";
      default_model = "claude-haiku-5-5";
      model_catalog = true;
      models = [
        {
          id = "claude-opus-5-5";
          reasoning = true;
          context_window = 1000000;
        }
        {
          id = "claude-sonnet-5-5";
          reasoning = true;
          context_window = 1000000;
        }
        {
          id = "claude-haiku-5-5";
          reasoning = true;
          context_window = 1000000;
        }
        {
          id = "gemini-3.8-flash";
          reasoning = true;
          context_window = 1048576;
        }
        {
          id = "gemini-3.8-flash-high";
          reasoning = true;
          context_window = 1048576;
        }
        {
          id = "gemini-pro-agent";
          reasoning = true;
          context_window = 1048576;
        }
        {
          id = "gemini-3.1-pro-low";
          reasoning = true;
          context_window = 1048576;
        }
        {
          id = "kimi-k3";
          reasoning = true;
          context_window = 1048576;
        }
      ];
    };
    closerouter = {
      type = "openai-compatible";
      base_url = "https://api.closerouter.dev/v1";
      api_key_env = "LITELLM_CLOSEROUTER";
      env_file = "closerouter.env";
      default_model = "deepseek/deepseek-v4.1-flash";
      model_catalog = true;
      models = [
        {
          id = "deepseek/deepseek-v4-pro-0813";
          reasoning = true;
          context_window = 1000000;
        }
        {
          id = "deepseek/deepseek-v4.1-flash";
          reasoning = true;
          context_window = 1000000;
        }
        {
          id = "qwen/qwen3.8-flash";
          reasoning = true;
          context_window = 1000000;
        }
        {
          id = "qwen/qwen3.8-max";
          reasoning = true;
          context_window = 1000000;
        }
      ];
    };
    llm-labile = {
      type = "openai-compatible";
      base_url = "https://llm.labile.cc/v1";
      api_key_env = "LITELLM_MASTER_KEY";
      env_file = "pool.env";
      default_model = "deepseek-v4.1-flash";
      model_catalog = true;
      supports_reasoning_effort = true;
      models = poolModels;
    };
    tokenharbor = {
      type = "openai-compatible";
      base_url = "https://tokenharbor.ai/v1";
      api_key_env = "TOKENHARBOR_API_KEY";
      env_file = "tokenharbor.env";
      default_model = "deepseek-v4-flash:free";
      model_catalog = true;
      models = [
        {
          id = "deepseek-v4-flash:free";
          reasoning = true;
          context_window = 1000000;
        }
      ];
    };
  };

  extensionProviders = config.jcode.extensions.providers;

  hasPoolCredential = (config.age.secrets.opencode-litellm-master-key or null) != null;

  defaultRoute =
    if hasPoolCredential then
      {
        provider = "llm-labile";
        model = "deepseek-v4.1-flash";
      }
    else
      {
        provider = "opencode-go";
        model = "deepseek-v4.1-flash";
      };

  providerNameCollisions = lib.attrNames (
    builtins.intersectAttrs baseProviders extensionProviders
  );
in
{
  inherit baseProviders extensionProviders defaultRoute providerNameCollisions;
}
