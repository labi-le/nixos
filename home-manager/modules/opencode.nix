{ pkgs
, lib
, osConfig
, ...
}:

let
  opencodeWrapped = pkgs.writeShellScriptBin "opencode" ''
    ${lib.optionalString (osConfig.age.secrets ? litellm-env) ''
      set -a
      . "${osConfig.age.secrets.litellm-env.path}"
      set +a
    ''}
    exec ${pkgs.opencode}/bin/opencode "$@"
  '';
  opencodeMcpGrafana = pkgs.writeShellScriptBin "opencode-mcp-grafana" ''
    ${lib.optionalString (osConfig.age.secrets ? opencode-grafana-mcp) ''
      set -a
      . "${osConfig.age.secrets.opencode-grafana-mcp.path}"
      set +a
    ''}
    exec ${pkgs.uv}/bin/uvx mcp-grafana
  '';
  opencodeMcpOpendataloaderPdf = pkgs.writeShellScriptBin "opencode-mcp-opendataloader-pdf" ''
    export JAVA_HOME="${pkgs.jre}"
    export PATH="${
      lib.makeBinPath [
        pkgs.jre
        pkgs.uv
      ]
    }:$PATH"
    exec ${pkgs.uv}/bin/uvx opendataloader-pdf-mcp
  '';
in

{
  home.shellAliases = {
    oo = "opencode";
  };

  home.packages = [
    (pkgs.python3Packages.buildPythonApplication rec {
      pname = "desloppify";
      version = "0.9.15";
      pyproject = true;

      src = pkgs.python3Packages.fetchPypi {
        inherit pname version;
        hash = "sha256-AXDPIBIvvRba50EQUA5iuXgdfdk/5di8GBlSjFXaPiI=";
      };

      build-system = with pkgs.python3Packages; [ setuptools ];
      dependencies = with pkgs.python3Packages; [
        tree-sitter
        tree-sitter-language-pack
        defusedxml
        bandit
        pillow
        pyyaml
      ];
      doCheck = false;
    })
  ];

  programs.opencode = {
    enable = true;
    package = opencodeWrapped;

    tui = {
      theme = lib.mkForce "opencode";
    };

    settings = {
      default_agent = "orchestrator";
      compaction = {
        auto = true;
        tail_turns = 14;
      };
      tool_output = {
        max_lines = 120;
        max_bytes = 12288;
      };
      provider = {
        litellm = {
          npm = "@ai-sdk/openai-compatible";
          name = "LiteLLM";
          options = {
            baseURL = "http://127.0.0.1:27015/v1";
            apiKey = "{env:LITELLM_MASTER_KEY}";
          };
          models = {
            "research-free" = {
              name = "research-free";
            };
          };
        };
      };
      agent = {
        orchestrator = {
          description = "Coordinates work and delegates independent tasks";
          mode = "primary";
          permission = {
            task = {
              "*" = "ask";
              "researcher" = "allow";
              "api-verifier" = "allow";
            };
          };
          prompt = ''
            Delegation Policy (mandatory)

            1) Before implementation, produce a dependency map:
            - List subtasks slave-1..slave-n.
            - For each subtask include type (implementation or research), touched files or data, and dependencies.
            - Mark each subtask as INDEPENDENT or COUPLED.

            1.1) Context budget policy (mandatory):
            - Keep only facts that directly change implementation or verification decisions.
            - Use a strict evidence budget: max 5 findings and max 2 evidence lines per finding.
            - If confidence >= 0.9, stop additional research and execute.
            - Never re-run identical research unless a new hypothesis appears.

            2) Hard delegation rule:
            - If there are two or more INDEPENDENT subtasks, delegate each independent cluster to a subagent.
            - If a task is research-only and does not require full session context, delegate it to subagent "researcher".
            - Any broad research activity (>= 3 files, external docs, or web lookup) must be delegated to "researcher".
            - Tiny lookup (<= 2 files and <= 1 grep) may stay local to avoid coordination overhead.
            - Any runtime API validation, endpoint reproduction, or curl-based fact-checking must be delegated to subagent "api-verifier".
            - The main agent must not execute delegable tasks itself.

            3) Non-delegation is allowed only when:
            - Shared state across subtasks is required.
            - Multiple subtasks will likely conflict heavily in the same files.
            - The work is trivial and atomic (single small change).

            4) For every delegated task provide:
            - Goal.
            - Strict scope and files to touch.
            - Non-goals.
            - Required output format.
            - Verification commands.

            4.1) For delegation to "api-verifier", the main agent must provide capability flags:
            - can_mutate_data: true|false
            - allowed_skills: [..]
            - allowed_envs: [..]
            - cleanup_required: true|false
            - expected_result: contract expectations
            - actual_result: current observed behavior

            4.2) Safety defaults:
            - If can_mutate_data is missing or false, api-verifier must run in read-only mode.
            - No destructive SQL or irreversible mutations.
            - Any mutation must be reported together with cleanup status.

            5) After subagents return:
            - Integrate results.
            - Resolve conflicts.
            - Run final verification.
            - Report what was delegated, why, and verification evidence.

            Required response sections:
            - For non-trivial tasks (>= 2 subtasks, or any delegation):
              - Decomposition
              - Delegation Plan
              - Execution
              - Verification
            - For trivial atomic tasks:
              - Execution
              - Verification

            Verification section policy:
            - Include only a compact summary with:
              - What was done
              - Why it was done
              - Verification evidence (commands and key results)
            - Do not include suggestions, alternatives, or next steps in Verification.

            Output policy:
            - Keep answers compact and avoid repeating tool output.
            - Prefer bullet points over long prose.
            - Include actionable next steps only when explicitly requested.
          '';
        };
        researcher = {
          description = "Performs any research task and returns concise evidence";
          mode = "subagent";
          model = "litellm/research-free";
          permission = {
            read = "allow";
            glob = "allow";
            grep = "allow";
            list = "allow";
            webfetch = "allow";
            websearch = "allow";
            lsp = "allow";
            edit = "deny";
            bash = "deny";
            task = "deny";
          };
          prompt = ''
            You are a research subagent.
            Scope: any research task that does not require editing files.
            Allowed: codebase exploration, file/symbol lookup, syntax checks, documentation lookup, and pattern discovery.
            Hard limits:
            - timebox: 10 minutes per request
            - max files opened: 15
            - max links followed: 15
            - max navigation depth from entrypoint: 2
            - stop when confidence >= 0.9 or when top 5 findings are complete
            Do not edit files.
            Return:
            - Findings (max 5)
            - Evidence (exact paths/line numbers/links, max 2 per finding)
            - Unknowns (max 3)
            - Suggested next action for orchestrator (exactly 1)
          '';
        };
        api-verifier = {
          description = "Validates API behavior via runtime checks and returns evidence-based verdicts";
          mode = "subagent";
          model = "opencode/deepseek-v4-flash-free";
          permission = {
            read = "allow";
            glob = "allow";
            grep = "allow";
            list = "allow";
            skill = "allow";
            bash = {
              "*" = "deny";
              "curl *" = "allow";
              "jq *" = "allow";
              "http *" = "allow";
              "docker exec *" = "allow";
              "docker compose exec *" = "allow";
            };
            edit = "deny";
            task = "deny";
          };
          prompt = ''
            You are an API verification subagent.
            Primary goal: verify API behavior against expected contract using runtime evidence.

            Input contract from orchestrator:
            - can_mutate_data: true|false
            - allowed_skills: [..]
            - allowed_envs: [..]
            - cleanup_required: true|false
            - expected_result
            - actual_result

            Safety rules:
            - If can_mutate_data is missing or false, operate strictly read-only.
            - Use only explicitly allowed skills.
            - Never perform destructive or irreversible operations.
            - If any test data/session is created, report changes and cleanup outcome.

            Return format:
            - Verdict: match | mismatch | inconclusive
            - Evidence: commands, status codes, key response fields
            - Expected vs Actual diff
            - Data changes: none | list
            - Cleanup status: done | not-required | failed
            - Suggested next action for orchestrator
          '';
        };
      };
      permission = {
        external_directory = {
          "/tmp/**" = "allow";
          "/nix/store/**" = "allow";
        };
        edit = {
          "/tmp/**" = "allow";
        };
        read = "allow";
        glob = "allow";
        grep = "allow";
        list = "allow";
      };
      plugin = [
        "opencode-gemini-auth@latest"
        # "opencode-openai-codex-auth@latest"
        "superpowers@git+https://github.com/obra/superpowers.git"
        "opencode-agent-skills@git+https://github.com/NickCao/agent-skills.git"
      ];
      mcp = {
        context7 = {
          type = "remote";
          url = "https://mcp.context7.com/mcp";
        };
        gh_grep = {
          type = "remote";
          url = "https://mcp.grep.app";
        };
        opendataloader-pdf = {
          type = "local";
          command = [ "${opencodeMcpOpendataloaderPdf}/bin/opencode-mcp-opendataloader-pdf" ];
        };
      }
      // lib.optionalAttrs (osConfig.age.secrets ? opencode-grafana-mcp) {
        grafana = {
          type = "local";
          command = [ "${opencodeMcpGrafana}/bin/opencode-mcp-grafana" ];
        };
      };
    };
    skills = {
      desloppify = "${
        pkgs.fetchFromGitHub {
          owner = "peteromallet";
          repo = "desloppify";
          rev = "3a7735d531a96b6a226bfbdc9fd662b14195f857";
          hash = "sha256-USFofGy0SUZV0oeh5x5KAWeFReD45GxlyYqpmc23NFM=";
        }
      }/docs";
      plantuml-rendering = "${pkgs.fetchFromGitHub {
        owner = "asolfre";
        repo = "plantuml-rendering-skill";
        rev = "5191edd2b30b8729a3ada1b61db381f3132d6764";
        hash = "sha256-SOkpdeAkC68unov70AseGrK3GB0FK/HdR9MxgsqaNr0=";
      }}";
      caveman = "${
        pkgs.fetchFromGitHub {
          owner = "JuliusBrussee";
          repo = "caveman";
          rev = "655b7d9c5431f822264b7732e9901c5578ac84cf";
          hash = "sha256-BydREt/vai3j7kO5+e1OxsjXf6Vy+jSY1yA/yyxjHbI=";
        }
      }/skills/caveman";
    };
  };
}
