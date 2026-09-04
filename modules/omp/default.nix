{
  config,
  lib,
  pkgs,
  inputs,
  user,
  ...
}:

let
  litellmSecret = config.age.secrets.opencode-litellm-master-key or null;
  litellmKey =
    envName:
    if litellmSecret != null then
      "!${pkgs.gnused}/bin/sed -n 's/^${envName}=//p' ${litellmSecret.path}"
    else
      envName;
  closerouterApiKey = litellmKey "LITELLM_CLOSEROUTER";

  userCfg = config.users.users.${user.name};
  agentDir = "${userCfg.home}/.omp/agent";

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

  skillLinks = lib.mapAttrsToList (
    name: dir: "L+ ${agentDir}/skills/${name} - - - - ${dir}"
  ) vendoredSkills;

  modelsYml = pkgs.writeText "models.yml" (
    builtins.toJSON {
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
            {
              id = "qwen/qwen3.8-max";
              name = "Qwen3.8 Max";
              reasoning = true;
              supportsTools = true;
              contextWindow = 1000000;
              maxTokens = 32768;
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
              input = [ "text" ];
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
    }
  );

  mcpJson = pkgs.writeText "mcp.json" (
    builtins.toJSON {
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
      };
    }
  );

  keybindingsYml = pkgs.writeText "keybindings.yml" (
    builtins.toJSON {
      "app.stt.toggle" = "Alt+S";
    }
  );

  repoRegisterJs = pkgs.writeText "repo-register.js" ''
    import { execFile, spawnSync } from "node:child_process";
    import { promisify } from "node:util";
    import { existsSync } from "node:fs";
    import { join } from "node:path";

    const run = promisify(execFile);
    const INDEX_REPO = "${pkgs.index-repo}/bin/index-repo";

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

  lspJson = pkgs.writeText "lsp.json" (
    builtins.toJSON {
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
            '')
            + "/bin/gopls";
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
    }
  );

  yaml = pkgs.formats.yaml { };
  configFile = yaml.generate "omp-config.yml" {
    setupVersion = 1;
    extensions = [ ];
    advisor.enabled = false;
    defaultThinkingLevel = "auto";
    memory.backend = "mnemopi";
    autoResume = true;
    modelRoleStorage = "project";
    compaction = {
      enabled = true;
      methodOrder = [
        "shake"
        "snapcompact"
        "remote"
        "soft"
      ];
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
      isolation.enabled = true;
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
      waitForUsageReset = true;
      maxDelayMs = 0;
      maxRetries = 1000;
    };
    async.pollWaitDuration = "1m";
    stt = {
      enabled = true;
      modelName = "balanced";
      language = "ru";
      submitTrigger = "never";
    };
  };
in
{
  imports = [ inputs.index-repo.nixosModules.default ];

  environment.systemPackages = [
    pkgs.omp
    pkgs.uv
    pkgs.nodejs
    pkgs.git
    pkgs.gh
  ];

  services.index-repo = {
    enable = true;
    host = "192.168.1.2";
    package = pkgs.index-repo;
    debounce = 15000;
  };

  users.users.${user.name}.linger = true;

  systemd.tmpfiles.rules = [
    "d ${agentDir} 0700 ${user.name} ${userCfg.group} -"
    "d ${agentDir}/skills 0700 ${user.name} ${userCfg.group} -"
    "d ${agentDir}/rules 0700 ${user.name} ${userCfg.group} -"
    "d ${agentDir}/extensions 0700 ${user.name} ${userCfg.group} -"
    "L+ ${agentDir}/models.yml - - - - ${modelsYml}"
    "L+ ${agentDir}/mcp.json - - - - ${mcpJson}"
    "L+ ${agentDir}/keybindings.yml - - - - ${keybindingsYml}"
    "L+ ${agentDir}/lsp.json - - - - ${lspJson}"
    "L+ ${agentDir}/AGENTS.md - - - - ${./AGENTS.md}"
    "L+ ${agentDir}/RULES.md - - - - ${./RULES.md}"
    "L+ ${agentDir}/rules/commit-style.md - - - - ${./rules/commit-style.md}"
    "L+ ${agentDir}/rules/code-comments.md - - - - ${./rules/code-comments.md}"
    "L+ ${agentDir}/rules/project-naming.md - - - - ${./rules/project-naming.md}"
    "L+ ${agentDir}/extensions/commit-gate.ts - - - - ${./extensions/commit-gate.ts}"
    "L+ ${agentDir}/extensions/comment-gate.ts - - - - ${./extensions/comment-gate.ts}"
    "L+ ${agentDir}/extensions/repo-register.js - - - - ${repoRegisterJs}"
  ]
  ++ skillLinks;

  system.activationScripts.ompConfig = lib.stringAfter [ "users" ] ''
    mkdir -p ${agentDir}
    install -m 600 -o ${user.name} -g ${userCfg.group} ${configFile} ${agentDir}/config.yml
  '';
}
