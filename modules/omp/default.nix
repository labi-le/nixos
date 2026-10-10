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

  tokenharborSecret = config.age.secrets.tokenharbor-env or null;
  tokenharborKey =
    if tokenharborSecret != null then
      "!${pkgs.gnused}/bin/sed -n 's/^TOKENHARBOR_API_KEY=//p' ${tokenharborSecret.path}"
    else
      "TOKENHARBOR_API_KEY";

  byesuSecret = config.age.secrets.byesu-env or null;
  byesuKey =
    if byesuSecret != null then
      "!${pkgs.gnused}/bin/sed -n 's/^BYESU_API_KEY=//p' ${byesuSecret.path}"
    else
      "BYESU_API_KEY";

  userCfg = config.users.users.${user.name};
  agentDir = "${userCfg.home}/.omp/agent";

  superpowersSrc = pkgs.fetchFromGitHub {
    owner = "obra";
    repo = "superpowers";
    rev = "8ca22dba9a94f28898bbce59f2537ff4d87c747d";
    hash = "sha256-BWPiXoXV+jePP+wn/Z+Af4iehIL7oei00plaWaTzq8s=";
  };
  humanizerSrc = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/databasus/databasus/bda7237599756ba76401b29e9761b07206e38bd6/.agents/skills/humanizer/SKILL.md";
    hash = "sha256-fDpFzjSCLTnVs0d08TwQsU2ent9I6EJ9n7/vg/Mt7LA=";
  };
  humanizerSkill = pkgs.runCommand "humanizer-skill" { } ''
    mkdir -p $out
    cp ${humanizerSrc} $out/SKILL.md
  '';

  skillsFromDir =
    dir:
    lib.mapAttrs (name: _: "${dir}/${name}") (
      lib.filterAttrs (name: type: type == "directory" && builtins.pathExists "${dir}/${name}/SKILL.md") (
        builtins.readDir dir
      )
    );

  vendoredSkills = skillsFromDir "${superpowersSrc}/skills" // {
    humanizer = "${humanizerSkill}";
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
              maxTokens = 32768;
            }
            {
              id = "deepseek/deepseek-v4.1-flash";
              name = "DeepSeek V4.1 Flash (CloseRouter)";
              reasoning = true;
              supportsTools = true;
              contextWindow = 1000000;
              maxTokens = 32768;
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
        tokenharbor = {
          baseUrl = "https://tokenharbor.ai/v1";
          api = "openai-completions";
          apiKey = tokenharborKey;
          models = [
            {
              id = "deepseek-v4-flash:free";
              name = "DeepSeek V4 Flash (Token Harbor, free tier)";
              reasoning = true;
              supportsTools = true;
              contextWindow = 1000000;
              maxTokens = 393216;
            }
          ];
        };
        byesu = {
          baseUrl = "https://byesu.com/v1";
          api = "openai-completions";
          apiKey = byesuKey;
          models = [
            {
              id = "claude-opus-5-5";
              name = "Claude Opus 5.5";
              reasoning = true;
              supportsTools = true;
            }
            {
              id = "claude-sonnet-5-5";
              name = "Claude Sonnet 5.5";
              reasoning = true;
              supportsTools = true;
            }
            {
              id = "claude-haiku-5-5";
              name = "Claude Haiku 5.5";
              reasoning = true;
              supportsTools = true;
            }
            {
              id = "gemini-3.8-flash";
              name = "Gemini 3.8 Flash";
              reasoning = true;
              supportsTools = true;
            }
            {
              id = "gemini-3.8-flash-high";
              name = "Gemini 3.8 Flash High";
              reasoning = true;
              supportsTools = true;
            }
            {
              id = "gemini-pro-agent";
              name = "Gemini Pro Agent";
              reasoning = true;
              supportsTools = true;
            }
            {
              id = "gemini-3.1-pro-low";
              name = "Gemini 3.1 Pro Low";
              reasoning = true;
              supportsTools = true;
            }
            {
              id = "kimi-k3";
              name = "Kimi K3";
              reasoning = true;
              supportsTools = true;
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
            "--from"
            "chroma-mcp"
            "--with"
            "pydantic<2.14"
            "--with"
            "chromadb==${config.services.chromadb.package.version}"
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
            config.services.index-repo.host
            "--port"
            (toString config.services.index-repo.port)
            "--ssl"
            (lib.boolToString config.services.index-repo.ssl)
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

  repoRegisterJs = pkgs.replaceVars "${inputs.index-repo}/hooks/omp/repo-register.js" {
    index_repo_bin = "${pkgs.index-repo}/bin/index-repo";
  };

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

  delegationGate = pkgs.runCommand "omp-delegation-gate" { } ''
    mkdir -p $out
    cp ${./extensions/delegation-gate.ts} $out/delegation-gate.ts
    cp ${./extensions/delegation-policy.ts} $out/delegation-policy.ts
  '';

  yaml = pkgs.formats.yaml { };
  configFile = yaml.generate "omp-config.yml" {
    setupVersion = 2;
    extensions = [ ];
    advisor.enabled = false;
    defaultThinkingLevel = "auto";
    extendedContext = true;
    memory.backend = "mnemopi";
    autoResume = true;
    modelRoleStorage = "project";
    modelRoles.dictation = "local/whisper-small";
    composer.tokenRate = true;
    hideThinkingBlock = false;
    compaction = {
      enabled = true;
      methodOrder = [
        "snapcompact"
        "shake"
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
      eager = "preferred";
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
    stt = {
      enabled = true;
      language = "ru";
      submitTrigger = "never";
    };
    spelling.autocomplete = "off";
  };
in
{
  imports = [ inputs.index-repo.nixosModules.default ];

  programs.omp = {
    enable = true;
    package = pkgs.omp;
  };

  environment.systemPackages = [
    pkgs.uv
    pkgs.nodejs
    pkgs.bun
    pkgs.git
    pkgs.gh
    pkgs.file
    pkgs.tinyxxd
    pkgs.bc
    pkgs.binutils-unwrapped
    pkgs.yq-go
    pkgs.sqlite
    pkgs.shellcheck
    (pkgs.python3.withPackages (ps: [
      ps.pyyaml
      ps.pillow
      ps.requests
    ]))
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
    "L+ ${agentDir}/rules/chroma-first.md - - - - ${./rules/chroma-first.md}"
    "L+ ${agentDir}/rules/chroma-first-shell.md - - - - ${./rules/chroma-first-shell.md}"
    "L+ ${agentDir}/extensions/commit-gate.ts - - - - ${./extensions/commit-gate.ts}"
    "L+ ${agentDir}/extensions/comment-gate.ts - - - - ${./extensions/comment-gate.ts}"
    "L+ ${agentDir}/extensions/git-upstream-gate.ts - - - - ${./extensions/git-upstream-gate.ts}"
    "L+ ${agentDir}/extensions/delegation-gate.ts - - - - ${delegationGate}/delegation-gate.ts"
    "L+ ${agentDir}/extensions/repo-register.js - - - - ${repoRegisterJs}"
  ]
  ++ skillLinks;

  system.activationScripts.ompConfig = lib.stringAfter [ "users" ] ''
    mkdir -p ${agentDir}
    install -m 600 -o ${user.name} -g ${userCfg.group} ${configFile} ${agentDir}/config.yml
  '';
}
