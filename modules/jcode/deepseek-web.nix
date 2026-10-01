{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.jcode.deepseekWeb;

  sessionHook = pkgs.writeShellScriptBin "jcode-deepseek-session" ''
    export FDS_PROFILE=${lib.escapeShellArg cfg.profileName}
    export FDS_PROXY=${lib.escapeShellArg cfg.endpoint}
    export FDS_KEY_PREFIX=${lib.escapeShellArg cfg.keyPrefix}
    export FDS_FALLBACK_KEY=${lib.escapeShellArg cfg.fallbackKey}
    export FDS_ENV_FILE=${lib.escapeShellArg cfg.envFileName}
    exec ${pkgs.python3}/bin/python3 ${./deepseek-session.py}
  '';

  models = [
    {
      id = "deepseek-v4-flash";
      reasoning = false;
      name = "DeepSeek-V4.1-Flash (local proxy)";
    }
    {
      id = "deepseek-v4-flash-thinking";
      reasoning = true;
      name = "DeepSeek-V4.1-Flash + DeepThink (local proxy)";
    }
    {
      id = "deepseek-v4-flash-search";
      reasoning = false;
      name = "DeepSeek-V4.1-Flash + native search (local proxy)";
    }
    {
      id = "deepseek-v4-flash-thinking-search";
      reasoning = true;
      name = "DeepSeek-V4.1-Flash + DeepThink + search (local proxy)";
    }
  ];
in
{
  options.jcode.deepseekWeb = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable the local FreeDeepseekAPI provider profile and the hook that
        keeps its proxy-side session in sync with the jcode session.
      '';
    };

    profileName = lib.mkOption {
      type = lib.types.str;
      default = "deepseek-web";
      description = "jcode provider profile name that points at the local proxy.";
    };

    endpoint = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:9655";
      description = "Local FreeDeepseekAPI base URL, without the /v1 suffix.";
    };

    envFileName = lib.mkOption {
      type = lib.types.str;
      default = "deepseek-web.env";
      description = ''
        File name under the jcode config directory that carries
        JCODE_OPENAI_EXTRA_BODY. The session hook rewrites it with the agent key
        of the current jcode session, and the provider picks that key up when it
        is built.
      '';
    };

    keyPrefix = lib.mkOption {
      type = lib.types.str;
      default = "jcode";
      description = "Prefix of the proxy agent key derived from the jcode session id.";
    };

    fallbackKey = lib.mkOption {
      type = lib.types.str;
      default = "jcode";
      description = "Agent key used until the session hook has written the env file.";
    };

    contextWindow = lib.mkOption {
      type = lib.types.int;
      default = 1048576;
      description = "Declared context window for the proxy models.";
    };
  };

  config = lib.mkIf cfg.enable {
    jcode.extensions = {
      providers.${cfg.profileName} = {
        type = "openai-compatible";
        base_url = "${cfg.endpoint}/v1";
        auth = "none";
        requires_api_key = false;
        default_model = "deepseek-v4-flash";
        env_file = cfg.envFileName;
        extra_body.session = cfg.fallbackKey;
        models = map (model: {
          inherit (model) id reasoning name;
          context_window = cfg.contextWindow;
          input = [ "text" "image" ];
        }) models;
      };

      hooks = {
        session_start = [ "${sessionHook}/bin/jcode-deepseek-session" ];
        turn_start = [ "${sessionHook}/bin/jcode-deepseek-session" ];
      };
    };
  };
}
