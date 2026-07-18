{ osConfig
, pkgs
, lib
, ...
}:

let
  # apiKey resolved at RUNTIME via omp `!command` support (execSync at models.yml
  # load): the secret is read from /run/agenix live, never baked into the
  # world-readable /nix/store. Guarded: the secret exists only on pc/notebook.
  litellmSecret = osConfig.age.secrets.opencode-litellm-master-key or null;
  aigateApiKey =
    if litellmSecret != null then
      "!${pkgs.gnused}/bin/sed -n 's/^LITELLM_AIGATE_API_KEY=//p' ${litellmSecret.path}"
    else
      "LITELLM_AIGATE_API_KEY";

  # --- Skills migrated from the (now-disabled) opencode module ---------------
  # Vendored from obra/superpowers + labi-le/agent-skills, plus three standalone
  # skills. Deployed to ~/.omp/agent/skills/<name> so omp's native provider
  # (priority 100) owns them independently of opencode. The
  # code-yeongyu/oh-my-openagent source was intentionally dropped.
  superpowersSrc = pkgs.fetchFromGitHub {
    owner = "obra";
    repo = "superpowers";
    rev = "896224c4b1879920ab573417e68fd51d2ccc9072";
    hash = "sha256-+lT2a/qq0SF4k0PgnEDKiuidVlZX2p0vEso4d/5T1os=";
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
    rev = "25d22f864ad68cc447a4cb93aefde918aa4aec9f";
    hash = "sha256-FbmfhFaPs/SnSZdfNdErdIUHXt1FfBzErpPpLy8kdIc=";
  };

  # { <name> = "<dir>/<name>"; } for every <name>/SKILL.md under `dir`. readDir
  # (IFD) auto-tracks the upstream skill set across rev bumps.
  skillsFromDir =
    dir:
    lib.mapAttrs (name: _: "${dir}/${name}") (
      lib.filterAttrs
        (name: type: type == "directory" && builtins.pathExists "${dir}/${name}/SKILL.md")
        (builtins.readDir dir)
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

  # index-repo auto-register extension, loaded via programs.oh-my-pi.extensions
  # below (the proven load path, same as omp-undo-redo). Registers the session's
  # git repo with the index-repo daemon so the chroma MCP has it indexed. Fires on
  # session_start (fresh launch) and agent_start (covers autoResume-resumed
  # sessions). `--pid` ties the registration to this omp process so the daemon GCs
  # it on exit; an exit handler unregisters promptly. Opt out per-repo with a
  # `.no-code-index` file, or globally with CODE_INDEXER_DISABLE=1.
  indexRepoRegisterExt = pkgs.writeText "omp-index-repo-register.js" ''
    import { execFile, spawnSync } from "node:child_process";
    import { promisify } from "node:util";
    import { existsSync } from "node:fs";
    import { join } from "node:path";

    const run = promisify(execFile);
    // Use the daemon's exact package so register (writes the marker name) always
    // matches the serve binary that reads it. pkgs.index-repo is a pinned release
    // (older `default`) and would write nameless markers -> daemon falls back.
    const INDEX_REPO = "${osConfig.services.index-repo.package}/bin/index-repo";

    async function ensureRegistered(ctx) {
      if (process.env.CODE_INDEXER_ACTIVE || process.env.CODE_INDEXER_DISABLE) return;
      const cwd = (ctx && ctx.cwd) || process.cwd();
      if (!cwd || !existsSync(join(cwd, ".git")) || existsSync(join(cwd, ".no-code-index"))) return;
      process.env.CODE_INDEXER_ACTIVE = "1";
      try { await run("systemctl", ["--user", "start", "--no-block", "index-repo.service"]); } catch {}
      try { await run(INDEX_REPO, ["register", cwd, "--pid", String(process.pid)]); } catch {}
      process.once("exit", () => {
        try { spawnSync(INDEX_REPO, ["unregister", cwd, "--pid", String(process.pid)]); } catch {}
      });
    }

    export default function (pi) {
      pi.on("session_start", (_event, ctx) => ensureRegistered(ctx));
      pi.on("agent_start", (_event, ctx) => ensureRegistered(ctx));
    }
  '';
in
{
  # `uv` provides `uvx`, required by the chroma MCP below. It used to come from
  # the now-disabled opencode module (opencode/packages.nix); keep it here so
  # the dependency lives next to the server that needs it. `nodejs` provides
  # `npx`/`node` on PATH for omp — npm-based MCP servers and tooling launched
  # from within the agent expect it.
  home.packages = [ pkgs.uv pkgs.nodejs ];

  programs.oh-my-pi = {
    enable = true;
    extensions = [ "${indexRepoRegisterExt}" ];

    providers = {
      aigate = {
        baseUrl = "https://api.aigate.shop/v1";
        api = "openai-completions";
        apiKey = aigateApiKey;
        models = [
          {
            id = "deepseek/deepseek-v4-pro";
            name = "DeepSeek V4 Pro";
            contextWindow = 200000;
            maxTokens = 8192;
          }
          {
            id = "deepseek/deepseek-v4-flash";
            name = "DeepSeek V4 Flash";
            contextWindow = 200000;
            maxTokens = 8192;
          }
          # ── Anthropic ──
          {
            id = "anthropic/claude-opus-4.8";
            name = "Claude Opus 4.8";
            contextWindow = 200000;
            maxTokens = 32768;
          }
          {
            id = "anthropic/claude-opus-4.7";
            name = "Claude Opus 4.7";
            contextWindow = 200000;
            maxTokens = 32768;
          }
          {
            id = "anthropic/claude-opus-4.6";
            name = "Claude Opus 4.6";
            contextWindow = 200000;
            maxTokens = 32768;
          }
          {
            id = "anthropic/claude-sonnet-5";
            name = "Claude Sonnet 5";
            contextWindow = 200000;
            maxTokens = 16384;
          }
          {
            id = "anthropic/claude-sonnet-4.6";
            name = "Claude Sonnet 4.6";
            contextWindow = 200000;
            maxTokens = 16384;
          }
          {
            id = "anthropic/claude-haiku-4.5";
            name = "Claude Haiku 4.5";
            contextWindow = 200000;
            maxTokens = 8192;
          }
          {
            id = "anthropic/claude-fable-5";
            name = "Claude Fable 5";
            contextWindow = 200000;
            maxTokens = 16384;
          }
          # ── OpenAI ──
          {
            id = "openai/gpt-5.5";
            name = "GPT-5.5";
            contextWindow = 128000;
            maxTokens = 16384;
          }
          {
            id = "openai/gpt-5.4";
            name = "GPT-5.4";
            contextWindow = 128000;
            maxTokens = 16384;
          }
          {
            id = "openai/gpt-5.4-mini";
            name = "GPT-5.4 Mini";
            contextWindow = 128000;
            maxTokens = 16384;
          }
          {
            id = "openai/gpt-5.4-nano";
            name = "GPT-5.4 Nano";
            contextWindow = 128000;
            maxTokens = 16384;
          }
          {
            id = "openai/gpt-image-2";
            name = "GPT Image 2";
            contextWindow = 128000;
            maxTokens = 4096;
          }
          # ── Google ──
          {
            id = "google/gemini-3.5-flash";
            name = "Gemini 3.5 Flash";
            contextWindow = 1048576;
            maxTokens = 8192;
          }
          {
            id = "google/gemini-3.1-pro-preview";
            name = "Gemini 3.1 Pro";
            contextWindow = 1048576;
            maxTokens = 8192;
          }
          {
            id = "google/gemini-3.1-flash-lite";
            name = "Gemini 3.1 Flash Lite";
            contextWindow = 1048576;
            maxTokens = 8192;
          }
          {
            id = "google/gemini-3.1-flash-lite-image";
            name = "Gemini 3.1 Flash Lite (Image)";
            contextWindow = 1048576;
            maxTokens = 8192;
          }
          {
            id = "google/gemini-3.1-flash-image-preview";
            name = "Gemini 3.1 Flash Image";
            contextWindow = 1048576;
            maxTokens = 8192;
          }
          {
            id = "google/gemini-3-flash-preview";
            name = "Gemini 3 Flash";
            contextWindow = 1048576;
            maxTokens = 8192;
          }
          {
            id = "google/gemini-3-pro-image";
            name = "Gemini 3 Pro Image";
            contextWindow = 1048576;
            maxTokens = 8192;
          }
          {
            id = "google/gemma-4-31b-it";
            name = "Gemma 4 31B";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          {
            id = "google/gemma-4-26b-a4b-it";
            name = "Gemma 4 26B A4B";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          # ── xAI ──
          {
            id = "x-ai/grok-4.5";
            name = "Grok 4.5";
            contextWindow = 128000;
            maxTokens = 16384;
          }
          {
            id = "x-ai/grok-4.3";
            name = "Grok 4.3";
            contextWindow = 128000;
            maxTokens = 16384;
          }
          {
            id = "x-ai/grok-4.20";
            name = "Grok 4.20";
            contextWindow = 128000;
            maxTokens = 16384;
          }
          {
            id = "x-ai/grok-4.1-fast";
            name = "Grok 4.1 Fast";
            contextWindow = 128000;
            maxTokens = 16384;
          }
          {
            id = "x-ai/grok-build-0.1";
            name = "Grok Build 0.1";
            contextWindow = 128000;
            maxTokens = 16384;
          }
          # ── Perplexity ──
          {
            id = "perplexity/sonar-pro";
            name = "Sonar Pro";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          {
            id = "perplexity/sonar-reasoning-pro";
            name = "Sonar Reasoning Pro";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          {
            id = "perplexity/sonar";
            name = "Sonar";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          # ── Qwen ──
          {
            id = "qwen/qwen3.7-max";
            name = "Qwen 3.7 Max";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          # ── Kimi (Moonshot) ──
          {
            id = "moonshotai/kimi-k2.7-code";
            name = "Kimi K2.7 Code";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          {
            id = "moonshotai/kimi-k2.7-code-highspeed";
            name = "Kimi K2.7 Code Highspeed";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          {
            id = "moonshotai/kimi-k2.6";
            name = "Kimi K2.6";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          # ── NVIDIA ──
          {
            id = "nvidia/nemotron-3-ultra";
            name = "Nemotron 3 Ultra";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          # ── Z.AI (GLM) ──
          {
            id = "z-ai/glm-5.2";
            name = "GLM 5.2";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          {
            id = "z-ai/glm-5.1";
            name = "GLM 5.1";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          # ── MiniMax ──
          {
            id = "minimax/minimax-m3";
            name = "MiniMax M3";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          {
            id = "minimax/minimax-m2.7";
            name = "MiniMax M2.7";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          # ── Sakana ──
          {
            id = "sakana/fugu-ultra";
            name = "Fugu Ultra";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          # ── Xiaomi ──
          {
            id = "xiaomi/mimo-v2.5-pro";
            name = "MiMo V2.5 Pro";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          {
            id = "xiaomi/mimo-v2.5";
            name = "MiMo V2.5";
            contextWindow = 128000;
            maxTokens = 8192;
          }
        ];
      };
    };

    models.default = "deepseek/deepseek-v4-pro";

    # On launch, resume the cwd's most-recent session in full (conversation +
    # its last model) instead of a fresh session that resets to models.default.
    settings.autoResume = true;

    # Context pruning ("DCP analog"): omp types only compaction.enabled, so the
    # rest ride the freeform `settings` (merged last into config.yml). snapcompact
    # is local/deterministic, no LLM or network cost, and the most token-frugal
    # strategy (auto-falls back to context-full for non-vision models).
    # midTurnEnabled prunes between tool-loop requests, not only post-turn;
    # dropUseless blanks zero-value results (empty search/inbox, timed-out poll).
    # Threshold left at the reserve-based default — it adapts to each model's
    # window (128k-1M here), unlike a fixed percent.
    settings.compaction = {
      enabled = true;
      strategy = "snapcompact";
      midTurnEnabled = true;
      dropUseless = true;
    };

    # Speech-to-text: local, offline dictation straight into the TUI editor.
    # parakeet = NVIDIA Parakeet TDT 0.6B v3 (sherpa-onnx), 25 languages incl.
    # Russian; SoTA default and fastest decoder. language=ru primes Russian
    # (whisper models honor it; parakeet auto-detects anyway). submitTrigger=never
    # keeps transcribed text in the editor for review instead of auto-sending.
    # Trigger: app.stt.toggle -> Alt+S (keybindings.yml below); the built-in
    # hold-Space push-to-talk gesture keeps working too. Model weights download
    # on first activation, then run warm from ~/.omp cache.
    settings.stt = {
      enabled = true;
      modelName = "parakeet";
      language = "ru";
      submitTrigger = "never";
    };
  };

  # User-scope MCP servers for omp (~/.omp/agent/mcp.json), merged with any
  # project-level <cwd>/.omp/mcp.json. `chroma` = semantic code search over the ChromaDB the
  # index-repo daemon builds (needs `uvx`/uv on PATH). `context7` = up-to-date
  # library docs. `sway` = query/control the running SwayWM session; the binary
  # is packaged declaratively (overlays.nix -> pkgs.swaywm-mcp) instead of
  # fetched at runtime via npx. SWAYSOCK is inherited from the session; SWAYMSG_BIN
  # is pinned so it works even when swaymsg is absent from PATH. Skills are
  # migrated from the (disabled) opencode module above.
  home.file = skillFiles // {
    ".omp/agent/mcp.json".text = builtins.toJSON {
      "$schema" = "https://raw.githubusercontent.com/can1357/oh-my-pi/main/packages/coding-agent/src/config/mcp-schema.json";
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
  };
}
