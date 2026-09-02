{ osConfig
, pkgs
, lib
, ...
}:

let
  # apiKey resolved at RUNTIME via omp `!command` support (execSync at models.yml
  # load): the secret is read from /run/agenix live, never baked into the
  # world-readable /nix/store. Guarded: the secret exists only on pc/notebook,
  # where the fallback is the plain env var name.
  litellmSecret = osConfig.age.secrets.opencode-litellm-master-key or null;
  litellmKey =
    envName:
    if litellmSecret != null then
      "!${pkgs.gnused}/bin/sed -n 's/^${envName}=//p' ${litellmSecret.path}"
    else
      envName;
  closerouterApiKey = litellmKey "LITELLM_CLOSEROUTER";

  # Single source of truth for the model omp runs on: models.default and the
  # advisor role below must stay identical, so they read the same binding.
  # `anthropic/claude-opus-5` is an exact provider/modelId match on the natively
  # authed account, and omp resolves that form before canonical coalescing or
  # bare-id lookup.
  mainModel = "anthropic/claude-opus-5";

  # Skills vendored from obra/superpowers + labi-le/agent-skills, plus three
  # standalone skills, deployed to ~/.omp/agent/skills/<name> for omp's native
  # provider (priority 100).
  superpowersSrc = pkgs.fetchFromGitHub {
    owner = "obra";
    repo = "superpowers";
    rev = "b36e0829c6d0140e93cfef2ca599b1b07d4a7797";
    hash = "sha256-EsGNO0dULWf5Bx6bGrCv2kI2Z8aKH0kRvGiuN23wChQ=";
  };
  agentSkillsSrc = pkgs.fetchFromGitHub {
    owner = "labi-le";
    repo = "agent-skills";
    rev = "57c9f2cf09ba23fe7962e73f0026dc545c4c6bc3";
    hash = "sha256-DUqUjWDqJk828se7ChbsZaflXfbvRNyQM+zU2psoDYU=";
  };
  desloppifySrc = pkgs.fetchFromGitHub {
    owner = "peteromallet";
    repo = "desloppify";
    rev = "3a7735d531a96b6a226bfbdc9fd662b14195f857";
    hash = "sha256-USFofGy0SUZV0oeh5x5KAWeFReD45GxlyYqpmc23NFM=";
  };
  plantumlSrc = pkgs.fetchFromGitHub {
    owner = "asolfre";
    repo = "plantuml-rendering-skill";
    rev = "5191edd2b30b8729a3ada1b61db381f3132d6764";
    hash = "sha256-SOkpdeAkC68unov70AseGrK3GB0FK/HdR9MxgsqaNr0=";
  };
  cavemanSrc = pkgs.fetchFromGitHub {
    owner = "JuliusBrussee";
    repo = "caveman";
    rev = "17f9f2ec2377b0bfe16b52ee03a462e7f0a02bc8";
    hash = "sha256-lmzmlPj47lWNRZudMSsdIocS4srZYQeG2bQw800Os7U=";
  };

  # { <name> = "<dir>/<name>"; } for every <name>/SKILL.md under `dir`. readDir
  # (IFD) auto-tracks the upstream skill set across rev bumps.
  skillsFromDir =
    dir:
    lib.mapAttrs (name: _: "${dir}/${name}") (
      lib.filterAttrs (name: type: type == "directory" && builtins.pathExists "${dir}/${name}/SKILL.md") (
        builtins.readDir dir
      )
    );

  vendoredSkills =
    skillsFromDir "${superpowersSrc}/skills"
    // skillsFromDir "${agentSkillsSrc}/skills"
    // {
      desloppify = "${desloppifySrc}/docs";
      plantuml-rendering = "${plantumlSrc}";
      caveman = "${cavemanSrc}/skills/caveman";
    };

  # ~/.omp/agent/skills/<name> -> upstream skill dir.
  skillFiles = lib.mapAttrs'
    (
      name: dir: lib.nameValuePair ".omp/agent/skills/${name}" { source = dir; }
    )
    vendoredSkills;

in
{
  # `uv` provides `uvx`, required by the chroma MCP below. `nodejs` provides
  # `npx`/`node` on PATH for omp — npm-based MCP servers and tooling launched
  # from within the agent expect it.
  home.packages = [
    pkgs.uv
    pkgs.nodejs
    pkgs.git
    pkgs.gh
  ];
  services.index-repo.omp.registerHook.enable = true;

  programs.omp = {
    enable = true;
    package = pkgs.omp;

    settings = {
      setupVersion = 1;

      extensions = [ ];

      modelRoles = {
        default = mainModel;
      };
      advisor.enabled = false;

      defaultThinkingLevel = "auto";

      memory.backend = "mnemopi";

      autoResume = true;
      modelRoleStorage = "project";

      compaction = {
        enabled = true;
        strategy = "snapcompact";
        midTurnEnabled = true;
        dropUseless = true;
        thresholdPercent = 60;
        keepRecentTokens = 40000;
        idleEnabled = true;
        idleThresholdTokens = 150000;
        idleTimeoutSeconds = 300;
      };

      mnemopi = {
        scoping = "per-project";
        embeddingVariant = "multilingual";
        polyphonicRecall = true;
        enhancedRecall = true;
        proactiveLinking = true;
      };

      autolearn.enabled = true;

      task = {
        eager = "always";
        enableLsp = true;
        maxRuntimeMs = 0;
        isolation.mode = "auto";
      };

      secrets.enabled = true;

      lsp = {
        diagnosticsOnEdit = true;
        formatOnWrite = true;
      };

      edit.autoRepair.enabled = true;

      eval.js = false;

      providers = {
        autoThinkingMaxEffort = "max";
        streamFirstEventTimeoutSeconds = 180;
        streamIdleTimeoutSeconds = 90;
      };

      retry = {
        modelFallback = false;
        usageAwareFallback = false;
      };

      async.pollWaitDuration = "1m";

      stt = {
        enabled = true;
        modelName = "balanced";
        language = "ru";
        submitTrigger = "never";
      };
    };
  };

  # User-scope MCP servers for omp (~/.omp/agent/mcp.json), merged with any
  # project-level <cwd>/.omp/mcp.json. `chroma` = semantic code search over the ChromaDB the
  # index-repo daemon builds (needs `uvx`/uv on PATH). `context7` = up-to-date
  # library docs. `sway` = query/control the running SwayWM session; the binary
  # is packaged declaratively (overlays.nix -> pkgs.swaywm-mcp) instead of
  # fetched at runtime via npx. SWAYSOCK is inherited from the session; SWAYMSG_BIN
  # is pinned so it works even when swaymsg is absent from PATH.
  home.file = skillFiles // {
    ".omp/agent/models.yml".text = builtins.toJSON {
      providers = {
        closerouter = {
          baseUrl = "https://api.closerouter.dev/v1";
          api = "openai-completions";
          apiKey = closerouterApiKey;
          models = [
            {
              id = "deepseek/deepseek-v4-pro-0813";
              name = "DeepSeek V4 Pro (CloseRouter)";
              reasoning = true;
              supportsTools = true;
              contextWindow = 1000000;
              maxTokens = 8192;
            }
            {
              id = "deepseek/deepseek-v4-flash-0731";
              name = "DeepSeek V4 Flash (CloseRouter)";
              reasoning = true;
              supportsTools = true;
              contextWindow = 1000000;
              maxTokens = 8192;
            }
          ];
        };
        llamacpp-local = {
          baseUrl = "http://192.168.1.2:8095/v1";
          api = "openai-completions";
          auth = "none";
          models = [
            {
              id = "qwen3.8-27b";
              name = "Qwen3.8 27B IQ3_XXS (pet)";
              reasoning = true;
              supportsTools = true;
              input = [
                "text"
              ];
              compat.reasoningContentField = "reasoning_content";
              contextWindow = 40960;
              maxTokens = 8192;
              cost = {
                input = 0;
                output = 0;
                cacheRead = 0;
                cacheWrite = 0;
              };
            }
          ];
        };
      };
    };
    ".omp/agent/RULES.md".source = ./omp/RULES.md;
    ".omp/agent/rules/commit-style.md".source = ./omp/rules/commit-style.md;
    ".omp/agent/rules/code-comments.md".source = ./omp/rules/code-comments.md;
    ".omp/agent/rules/project-naming.md".source = ./omp/rules/project-naming.md;
    # Enforces the commit-style rule above as a tool_call gate; a rule alone is
    # only context, and context is exactly what a long session loses first.
    ".omp/agent/extensions/commit-gate.ts".source = ./omp/extensions/commit-gate.ts;
    # Same for the code-comments rule: markers, commented-out code and real
    # production data in comments are mechanical, so they are refused, not advised.
    ".omp/agent/extensions/comment-gate.ts".source = ./omp/extensions/comment-gate.ts;
    ".omp/agent/AGENTS.md".source = ./omp/AGENTS.md;
    ".omp/agent/mcp.json".text = builtins.toJSON {
      "$schema" =
        "https://raw.githubusercontent.com/can1357/oh-my-pi/main/packages/coding-agent/src/config/mcp-schema.json";
      mcpServers = {
        chroma = {
          type = "stdio";
          command = "uvx";
          args = [
            "chroma-mcp"
            "--client-type"
            "http"
            "--host"
            "192.168.1.2"
            "--port"
            "8000"
            "--ssl"
            "false"
          ];
        };
        context7 = {
          type = "http";
          url = "https://mcp.context7.com/mcp";
        };
        sway = {
          type = "stdio";
          command = "${pkgs.swaywm-mcp}/bin/swaywm-mcp";
          env = {
            NODE_ENV = "production";
            SWAYMSG_BIN = "${pkgs.swayfx}/bin/swaymsg";
            # omp runs under tmux, whose server captured an env without SWAYSOCK,
            # so swaymsg can't find the IPC socket. The socket path is per-sway-pid
            # and dynamic; resolve it at server launch via omp's `!command` env
            # feature (newest sway-ipc socket for this uid). Re-run `/mcp reconnect
            # sway` after a sway restart to pick up the new socket.
            SWAYSOCK = "!ls -t \"$XDG_RUNTIME_DIR\"/sway-ipc.*.sock 2>/dev/null | head -1";
          };
        };
      };
    };
    # Press-to-toggle dictation (alternative to the default hold-Space gesture).
    ".omp/agent/keybindings.yml".text = builtins.toJSON {
      "app.stt.toggle" = "Alt+S";
    };
    ".omp/agent/lsp.json".text = builtins.toJSON {
      servers = {
        nixd = {
          command = "${pkgs.nixd}/bin/nixd";
          args = [ ];
          fileTypes = [ ".nix" ];
        };
        gopls = {
          command =
            (pkgs.writeShellScriptBin "gopls" ''
              export PATH=${lib.makeBinPath [ pkgs.go ]}:$PATH
              exec ${pkgs.gopls}/bin/gopls "$@"
            '') + "/bin/gopls";
          args = [ ];
          fileTypes = [ ".go" ];
        };
        biome = {
          command = "${pkgs.biome}/bin/biome";
          args = [ "lsp-proxy" ];
          fileTypes = [
            ".ts"
            ".tsx"
            ".js"
            ".jsx"
            ".mjs"
            ".cjs"
            ".mts"
            ".cts"
            ".json"
            ".jsonc"
            ".vue"
            ".astro"
            ".svelte"
            ".css"
            ".graphql"
            ".gql"
            ".html"
          ];
        };
        phpactor = {
          command = "${pkgs.phpactor}/bin/phpactor";
          args = [ "language-server" ];
          fileTypes = [ ".php" ];
        };
      };
    };
  };
}
