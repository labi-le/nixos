{
  config,
  lib,
  pkgs,
  user,
  ...
}:

let
  userName = user.name;
  userCfg = config.users.users.${userName};
  homeDirectory = userCfg.home;
  jcodeDir = "${homeDirectory}/.jcode";
  configDir = "${homeDirectory}/.config/jcode";

  superpowersSrc = pkgs.fetchFromGitHub {
    owner = "obra";
    repo = "superpowers";
    rev = "8ca22dba9a94f28898bbce59f2537ff4d87c747d";
    hash = "sha256-BWPiXoXV+jePP+wn/Z+Af4iehIL7oei00plaWaTzq8s=";
  };
  cavemanSrc = pkgs.fetchFromGitHub {
    owner = "JuliusBrussee";
    repo = "caveman";
    rev = "2fd153c67988e980fb0b2455c90832159a6a5a25";
    hash = "sha256-KFfU8LmNajKLZcOXOFisn4beTcg2YL+rpasr39UgSZE=";
  };
  agentSkillsSrc = pkgs.fetchFromGitHub {
    owner = "labi-le";
    repo = "agent-skills";
    rev = "57c9f2cf09ba23fe7962e73f0026dc545c4c6bc3";
    hash = "sha256-DUqUjWDqJk828se7ChbsZaflXfbvRNyQM+zU2psoDYU=";
  };
  plantumlSkillSrc = pkgs.fetchFromGitHub {
    owner = "asolfre";
    repo = "plantuml-rendering-skill";
    rev = "5191edd2b30b8729a3ada1b61db381f3132d6764";
    hash = "sha256-SOkpdeAkC68unov70AseGrK3GB0FK/HdR9MxgsqaNr0=";
  };
  humanizerSrc = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/databasus/databasus/bda7237599756ba76401b29e9761b07206e38bd6/.agents/skills/humanizer/SKILL.md";
    hash = "sha256-fDpFzjSCLTnVs0d08TwQsU2ent9I6EJ9n7/vg/Mt7LA=";
  };
  humanizerSkill = pkgs.runCommand "jcode-humanizer-skill" { } ''
    mkdir -p $out
    cp ${humanizerSrc} $out/SKILL.md
  '';

  skillsFromDir =
    dir:
    lib.mapAttrs (name: _: "${dir}/${name}") (
      lib.filterAttrs (
        name: type: type == "directory" && builtins.pathExists "${dir}/${name}/SKILL.md"
      ) (builtins.readDir dir)
    );

  vendoredSkills = lib.mergeAttrsList [
    (skillsFromDir "${superpowersSrc}/skills")
    (skillsFromDir "${agentSkillsSrc}/skills")
    {
      caveman = "${cavemanSrc}/skills/caveman";
      humanizer = humanizerSkill;
      plantuml-rendering = plantumlSkillSrc;
    }
  ];

  skillLinks = lib.mapAttrsToList (
    name: dir: "L+ ${jcodeDir}/skills/${name} - - - - ${dir}"
  ) vendoredSkills;

  mcpJson = pkgs.writeText "jcode-mcp.json" (
    builtins.toJSON {
      mcpServers = {
        chroma = {
          type = "stdio";
          command = "uvx";
          args = [
            "--from"
            "chroma-mcp"
            "--with"
            "pydantic<2.14"
            "python"
            "-c"
            ''
              import functools
              import sys
              import chroma_mcp.server as server

              server.print = functools.partial(print, file=sys.stderr)
              server.main()
            ''
            "--client-type"
            "http"
            "--host"
            "192.168.1.2"
            "--port"
            "8000"
            "--ssl"
            "false"
          ];
          timeout_secs = 120;
        };
        context7 = {
          type = "stdio";
          command = "${pkgs.mcp-proxy}/bin/mcp-proxy";
          args = [
            "--transport"
            "streamablehttp"
            "https://mcp.context7.com/mcp"
          ];
          timeout_secs = 60;
        };
      };
    }
  );

  commitGate = pkgs.writeShellScriptBin "jcode-commit-gate" ''
    exec ${pkgs.python3}/bin/python3 ${./commit-gate.py}
  '';

  commentGate = pkgs.writeShellScriptBin "jcode-comment-gate" ''
    exec ${pkgs.python3}/bin/python3 ${./comment-gate.py}
  '';

  upstreamGate = pkgs.writeShellScriptBin "jcode-upstream-gate" ''
    exec ${pkgs.python3}/bin/python3 ${./git_upstream_gate.py}
  '';

  repoRegister = pkgs.writeTextFile {
    name = "jcode-repo-register";
    executable = true;
    text = builtins.replaceStrings [ "@indexRepo@" ] [ "${pkgs.index-repo}" ] (
      builtins.readFile ./repo-register.sh
    );
  };

  baseProviders = {
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
          id = "qwen/qwen3.8-max";
          reasoning = true;
          context_window = 1000000;
        }
      ];
    };
    deepseek-pool = {
      type = "openai-compatible";
      base_url = "https://llm.labile.cc/v1";
      api_key_env = "LITELLM_MASTER_KEY";
      env_file = "pool.env";
      default_model = "opencode-go-pool";
      model_catalog = true;
      supports_reasoning_effort = true;
      models = [
        {
          id = "opencode-go-pool";
          reasoning = true;
          context_window = 1000000;
          input = [ "text" "image" ];
        }
      ];
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
        provider = "deepseek-pool";
        model = "opencode-go-pool";
      }
    else
      {
        provider = "opencode-go";
        model = "deepseek-v4.1-flash";
      };

  providerNameCollisions = lib.attrNames (
    builtins.intersectAttrs baseProviders extensionProviders
  );

  toml = pkgs.formats.toml { };
  configFile = toml.generate "jcode-config.toml" {
    server = {
      wake_mode = "internal";
    };

    keybindings = {
      scroll_up = "ctrl+shift+k";
      scroll_down = "ctrl+shift+j";
      scroll_page_up = "alt+u";
      scroll_page_down = "alt+d";
      model_switch_next = "ctrl+tab";
      model_switch_prev = "ctrl+shift+tab";
      fallback_switch = "ctrl+y";
      effort_increase = "alt+right";
      effort_decrease = "alt+left";
      centered_toggle = "alt+c";
      scroll_prompt_up = "ctrl+k";
      scroll_prompt_down = "ctrl+j";
      scroll_bookmark = "ctrl+g";
      auto_poke_toggle = "ctrl+p";
      scroll_up_fallback = "";
      scroll_down_fallback = "";
      workspace_left = "alt+h";
      workspace_down = "alt+j";
      workspace_up = "alt+k";
      workspace_right = "alt+l";
      side_panel_toggle = "alt+m";
      copy_selection_toggle = "alt+y";
      diagram_pane_toggle = "alt+t";
      diagram_pane_visibility_toggle = "alt+shift+m";
      typing_scroll_lock_toggle = "alt+s";
      diff_mode_cycle = "alt+g";
      info_widget_toggle = "alt+i";
      todo_card_toggle = "alt+x";
      swarm_panel_focus = "alt+n";
      new_terminal = "alt+shift+;";
      open_resume = "alt+r";
      voice_input = "ctrl+space";
      session_picker_enter = "current-terminal";
    };

    dictation = {
      command = "";
      mode = "send";
      timeout_secs = 90;
      vocabulary = [ ];
      recorder = "";
    };

    display = {
      diff_mode = "inline";
      queue_mode = false;
      auto_server_reload = true;
      mouse_capture = true;
      debug_socket = false;
      emoji = true;
      centered = false;
      show_thinking = true;
      reasoning_display = "full";
      diagram_mode = "none";
      markdown_spacing = "compact";
      latex_rendering = "image";
      pin_images = true;
      pin_todos = true;
      idle_animation = false;
      prompt_entry_animation = true;
      disabled_animations = [ ];
      performance = "";
      animation_fps = 60;
      redraw_fps = 60;
      prompt_preview = true;
      compact_notifications = false;
      copy_badge_alt_label = "";
      show_agentgrep_output = false;
      show_bash_output = true;
      tool_call_details = true;
      keybinding_hints = true;
      theme = "";
      active_sessions_manager = false;
      external_sessions = true;
      usage_display = "left";
      native_scrollbars = {
        chat = true;
        side_panel = true;
      };
      colors = {
        user = "#8be9fd";
        ai = "#50fa7b";
        tool = "#6272a4";
        file_link = "#8be9fd";
        dim = "#6272a4";
        accent = "#bd93f9";
        system = "#ff79c6";
        queued = "#f1fa8c";
        asap = "#ff79c6";
        pending = "#6272a4";
        user_text = "#f8f8f2";
        user_bg = "#44475a";
        ai_text = "#f8f8f2";
        header_icon = "#8be9fd";
        header_name = "#bd93f9";
        header_session = "#f8f8f2";
        success = "#50fa7b";
        warning = "#ffb86c";
        error = "#ff5555";
        info = "#bd93f9";
        border = "#6272a4";
        selection_bg = "#44475a";
      };
    };

    features = {
      check_updates = false;
      memory = true;
      swarm = true;
      mermaid = true;
      auto_poke = true;
      message_timestamps = true;
      persist_memory_injections = false;
      kv_cache_miss_notices = true;
      update_channel = "stable";
    };

    websearch = {
      engine = "duckduckgo";
      fallback_engines = [ "bing" ];
      bing_api_key_env = "JCODE_BING_API_KEY";
      bing_market = "en-US";
      searxng_url_env = "JCODE_SEARXNG_URL";
    };

    tools = {
      profile = "";
      enabled = [ ];
      disabled = [ ];
      disable_base_tools = false;
      mcp_tools = "auto";
      mcp_tools_token_threshold = 8000;
    };

    acp = {
      profile = "standard";
      tool_profile = "acp";
    };

    auth = {
      trusted_external_sources = [ ];
      trusted_external_source_paths = [
        "claude_code_credentials|${homeDirectory}/.claude/.credentials.json"
        "opencode_auth_json|${homeDirectory}/.local/share/opencode/auth.json"
      ];
    };

    provider = {
      default_model = defaultRoute.model;
      default_provider = defaultRoute.provider;
      openai_reasoning_effort = "low";
      anthropic_cache_ttl_1h = true;
      openai_service_tier = "priority";
      openai_native_compaction_mode = "auto";
      openai_native_compaction_threshold_tokens = 200000;
      preserve_reasoning_context = true;
      cross_provider_failover = "countdown";
      same_provider_account_failover = true;
      gemini_force_oauth = false;
      stream_idle_timeout_secs = 180;
      max_retries = 8;
      retry_backoff_cap_secs = 30;
    };

    agents = {
      swarm_spawn_mode = "inline";
      swarm_strip_layout = "vertical";
      memory_jev_provider = "auto";
      memory_jev_threshold = 0.8;
      memory_sidecar_enabled = true;
      memory_rerank_cadence = 3;
      memory_rerank_votes = 2;
      memory_rerank_min_agree = 2;
      swarm_max_concurrent_agents = 32;
    };

    hooks = {
      pre_tool = [
        "${commitGate}/bin/jcode-commit-gate"
        "${commentGate}/bin/jcode-comment-gate"
        "${upstreamGate}/bin/jcode-upstream-gate"
      ];
      session_start = [ "${repoRegister} start" ] ++ config.jcode.extensions.hooks.session_start;
      turn_start = [ "${repoRegister} start" ] ++ config.jcode.extensions.hooks.turn_start;
      pre_tool_transform_timeout_ms = 500;
      pre_tool_timeout_ms = 8000;
    };

    providers = baseProviders // extensionProviders;

    ambient = {
      enabled = false;
      allow_api_keys = false;
      min_interval_minutes = 5;
      max_interval_minutes = 120;
      pause_on_active_session = true;
      proactive_work = true;
      work_branch_prefix = "ambient/";
      visible = true;
    };

    safety = {
      ntfy_server = "https://ntfy.sh";
      desktop_notifications = true;
      email_enabled = false;
      email_smtp_port = 587;
      email_imap_port = 993;
      email_reply_enabled = false;
      telegram_enabled = false;
      telegram_reply_enabled = false;
      discord_enabled = false;
      discord_reply_enabled = false;
      jade_relay_enabled = false;
      jade_relay_reply_enabled = false;
      jade_relay_launch_enabled = false;
    };

    notifications = {
      turn_complete = true;
      turn_complete_min_secs = 120;
      turn_complete_todo_min_secs = 30;
      turn_complete_only_when_unfocused = true;
      turn_complete_sound = "Glass";
    };

    gateway = {
      enabled = false;
      port = 7643;
      bind_addr = "0.0.0.0";
    };

    compaction = {
      mode = "proactive";
      lookahead_turns = 15;
      ewma_alpha = 0.3;
      proactive_floor = 0.4;
      min_samples = 3;
      stall_window = 5;
      min_turns_between_compactions = 10;
      max_context_tokens = 0;
    };

    power = {
      prevent_sleep_while_streaming = true;
      block_lid_close = true;
    };

    autoreview = {
      enabled = false;
    };

    autojudge = {
      enabled = false;
    };

    launch_hotkeys = {
      enabled = true;
      imported = true;
      entries = [
        {
          chord = "cmd+;";
          dir = "${homeDirectory}/nix";
          label = "nix";
          self_dev = false;
        }
        {
          chord = "cmd+'";
          dir = "$HOME";
          label = "home";
          self_dev = false;
        }
      ];
    };
  };

  providerEnvFiles = [
    {
      secret = "opencode-litellm-master-key";
      variable = "LITELLM_CLOSEROUTER";
      file = "closerouter.env";
    }
    {
      secret = "tokenharbor-env";
      variable = "TOKENHARBOR_API_KEY";
      file = "tokenharbor.env";
    }
    {
      secret = "opencode-litellm-master-key";
      variable = "LITELLM_MASTER_KEY";
      file = "pool.env";
    }
  ];

  writeProviderEnv =
    entry:
    let
      source = "/run/agenix/${entry.secret}";
    in
    ''
      if [ -r ${source} ]; then
        value="$(${pkgs.gnused}/bin/sed -n 's/^${entry.variable}=//p' ${source} | ${pkgs.coreutils}/bin/head -n1)"
        if [ -n "$value" ]; then
          printf '%s=%s\n' '${entry.variable}' "$value" > "${configDir}/${entry.file}"
          chmod 600 "${configDir}/${entry.file}"
          chown ${userName}:${userCfg.group} "${configDir}/${entry.file}"
        fi
      fi
    '';
in
{
  imports = [
    ./deepseek-web.nix
    ./space-bunny.nix
  ];

  options.jcode.extensions = {
    providers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      default = { };
      description = ''
        Extra jcode provider profiles, merged into the generated config.toml.
        Plug-in modules such as modules/jcode/deepseek-web.nix use this instead
        of editing the profile list inline.
      '';
    };

    hooks = lib.mkOption {
      type = lib.types.submodule {
        options = {
          session_start = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Extra session_start hook commands, appended after the built-in ones.";
          };
          turn_start = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Extra turn_start hook commands, appended after the built-in ones.";
          };
        };
      };
      default = { };
      description = "Extra jcode hook commands contributed by plug-in modules.";
    };
  };

  config = {
    assertions = [
      {
        assertion = providerNameCollisions == [ ];
        message = "jcode.extensions.providers redefines built-in jcode profiles: ${
          lib.concatStringsSep ", " providerNameCollisions
        }";
      }
    ];

    systemd.tmpfiles.rules = [
      "d ${jcodeDir} 0700 ${userName} ${userCfg.group} -"
      "d ${jcodeDir}/skills 0700 ${userName} ${userCfg.group} -"
      "d ${configDir} 0700 ${userName} ${userCfg.group} -"
      "f ${jcodeDir}/no_telemetry 0600 ${userName} ${userCfg.group} -"
      "L+ ${jcodeDir}/mcp.json - - - - ${mcpJson}"
      "L+ ${jcodeDir}/config.toml - - - - ${configFile}"
      "L+ ${jcodeDir}/prompt-overlay.md - - - - ${./prompt-overlay.md}"
      "L+ ${homeDirectory}/AGENTS.md - - - - ${./AGENTS.md}"
    ]
    ++ skillLinks;

    system.activationScripts.jcodeProviderEnv = lib.stringAfter [ "users" ] ''
      mkdir -p ${jcodeDir} ${configDir}
      chown ${userName}:${userCfg.group} ${jcodeDir} ${configDir}
      ${builtins.concatStringsSep "\n" (map writeProviderEnv providerEnvFiles)}
    '';
  };
}
