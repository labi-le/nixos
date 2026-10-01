{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.jcode.deepseekWeb;

  sessionHook = pkgs.writeShellScriptBin "jcode-deepseek-session" ''
    export FDS_PROXY=${lib.escapeShellArg cfg.endpoint}
    export FDS_AGENT_KEY=${lib.escapeShellArg cfg.agentKey}
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
        starts a fresh proxy chat whenever the jcode session behind the shared
        proxy agent changes.
      '';
    };

    profileName = lib.mkOption {
      type = lib.types.strMatching "[A-Za-z0-9_-]+";
      default = "deepseek-web";
      description = "jcode provider profile name that points at the local proxy.";
    };

    endpoint = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:9655";
      description = "Local FreeDeepseekAPI base URL, without the /v1 suffix.";
    };

    envFileName = lib.mkOption {
      type = lib.types.strMatching "[A-Za-z0-9_-]+(\\.[A-Za-z0-9_-]+)*";
      default = "deepseek-web.env";
      description = ''
        File name under the jcode config directory that carries
        JCODE_OPENAI_EXTRA_BODY. The session hook rewrites it with the proxy
        agent key, and the provider picks that key up when it is built.
      '';
    };

    agentKey = lib.mkOption {
      type = lib.types.strMatching "[A-Za-z0-9._-]+";
      default = "jcode";
      description = ''
        Single proxy agent key. The proxy is sticky per key, so every jcode
        session shares one agent and the hook starts a new proxy chat on the
        key whenever the owning jcode session changes. The agent key has to
        stay constant: the provider resolves extra_body once, when the server
        builds it, so a key derived from the session id would be frozen for the
        life of that server.
      '';
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
        extra_body.session = cfg.agentKey;
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
