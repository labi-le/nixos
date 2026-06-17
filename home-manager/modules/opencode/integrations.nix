{
  pkgs,
  lib,
  osConfig,
  ...
}:

let
  wrappers = import ./wrappers.nix {
    inherit
      pkgs
      lib
      osConfig
      ;
  };
  chromaGate = pkgs.writeText "chroma-gate.ts" ''
    import type { Plugin } from "@opencode-ai/plugin"

    const CHROMA_SEARCH_RULE = [
      "MANDATORY codebase search: call chroma_query_documents FIRST. Collection: code-<basename of workspace root> (this workspace: code-nixos).",
      "Use grep/glob only after a chroma call, when you already know the exact file path, or when chroma is empty/missing.",
      "Never bypass chroma with bash search (rg/grep/find). 'I'll just grep quickly' / 'too simple for search' are not valid reasons — chroma first.",
      "Enforced by the chroma-gate plugin: grep/glob without a prior chroma call are blocked.",
    ].join("\n")

    const chromaCalled = new Set<string>()
    const sessionAgent = new Map<string, string>()

    const ENFORCED_AGENTS = new Set<string>([
      "build",
      "orchestrator",
      "general",
      "explore",
      "explorer",
      "plan",
    ])

    const isChromaQuery = (name: string) =>
      name === "chroma_query_documents" ||
      name.endsWith("_chroma_query_documents") ||
      (name.toLowerCase().includes("chroma") && name.toLowerCase().includes("query"))

    const isGrep = (name: string) => name === "grep" || name.endsWith("_grep")
    const isGlob = (name: string) => name === "glob" || name.endsWith("_glob")

    const isNarrowedGrep = (args: any) => {
      if (!args || typeof args !== "object") return false
      const hasInclude = typeof args.include === "string" && args.include.length > 0
      const path = typeof args.path === "string" ? args.path : ""
      const hasConcretePath =
        path.length > 0 && path !== "." && path !== "/" && !path.endsWith("/**")
      return hasInclude && hasConcretePath
    }

    const isNarrowedGlob = (args: any) => {
      if (!args || typeof args !== "object") return false
      const path = typeof args.path === "string" ? args.path : ""
      const pattern = typeof args.pattern === "string" ? args.pattern : ""
      if (path.length > 0 && path !== "." && path !== "/") return true
      if (pattern && !pattern.startsWith("**") && !pattern.startsWith("/**")) return true
      return false
    }

    const rememberAgent = (sessionID: unknown, agent: unknown) => {
      const sid = typeof sessionID === "string" ? sessionID : ""
      const ag = typeof agent === "string" ? agent : ""
      if (sid && ag) sessionAgent.set(sid, ag)
    }

    const blockMessage = (tool: string) =>
      [
        "BLOCKED by chroma-gate: " + tool + " requires a prior chroma_query_documents call in this session.",
        "Action: call chroma_query_documents first (collection name: code-<basename of workspace root>, e.g. code-nixos).",
        "Exception: " + tool + " is allowed without chroma only when narrowed by both args.path AND args.include (grep) or args.path/args.pattern targeting a specific subtree (glob).",
      ].join(" ")

    export default (async () => ({
      "experimental.chat.system.transform": async (_input, output) => {
        if (!Array.isArray(output.system) || output.system.length === 0) return
        if (!output.system.includes(CHROMA_SEARCH_RULE)) {
          output.system.splice(1, 0, CHROMA_SEARCH_RULE)
        }
      },
      "chat.message": async (input) => {
        rememberAgent(input.sessionID, (input as any).agent)
      },
      "chat.params": async (input) => {
        rememberAgent(input.sessionID, (input as any).agent)
      },
      "tool.execute.before": async (input, output) => {
        const tool = String(input.tool ?? "")
        const sessionID = String(input.sessionID ?? "")

        if (isChromaQuery(tool)) {
          if (sessionID) chromaCalled.add(sessionID)
          return
        }

        if (!isGrep(tool) && !isGlob(tool)) return

        const agent = sessionAgent.get(sessionID)
        if (!agent || !ENFORCED_AGENTS.has(agent)) return

        if (chromaCalled.has(sessionID)) return

        const args = output?.args
        if (isGrep(tool) && isNarrowedGrep(args)) return
        if (isGlob(tool) && isNarrowedGlob(args)) return

        throw new Error(blockMessage(tool))
      },
    })) satisfies Plugin
  '';
in

{
  programs.opencode.settings = {
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
      "@tarquinen/opencode-dcp@latest"
      "opencode-gemini-auth@latest"
      "@ex-machina/opencode-anthropic-auth@latest"
      "opencode-agent-skills@git+https://github.com/labi-le/agent-skills.git"
      "oh-my-openagent@latest"
      "superpowers@git+https://github.com/obra/superpowers.git"
    ];
    mcp = {
      context7 = {
        type = "remote";
        url = "https://mcp.context7.com/mcp";
      };
      chroma = {
        type = "local";
        command = [
          "uvx"
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
        timeout = 30000;
        enabled = true;
      };
      # opendataloader-pdf = {
      #   type = "local";
      #   command = [ "${wrappers.opencodeMcpOpendataloaderPdf}/bin/opencode-mcp-opendataloader-pdf" ];
      # };
    };
  };

  programs.opencode.skills = {
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

  xdg.configFile."opencode/plugins/chroma-gate.ts".source = chromaGate;
  xdg.configFile."opencode/plugins/rtk.ts".source = "${wrappers.rtkSource}/hooks/opencode/rtk.ts";

  xdg.configFile."opencode/oh-my-openagent.jsonc".text = builtins.toJSON {
    team_mode = {
      enabled = true;
      max_parallel_members = 8;
      tmux_visualization = true;
    };
    background_task = {
      defaultConcurrency = 10;
    };

    agents = {
      sisyphus = {
        model = "anthropic/claude-opus-4-8";
      };
      prometheus = {
        model = "anthropic/claude-opus-4-8";
      };
      metis = {
        model = "anthropic/claude-sonnet-4-6";
      };
      atlas = {
        model = "anthropic/claude-sonnet-4-6";
      };
      multimodal-looker = {
        model = "anthropic/claude-opus-4-8";
      };
      hephaestus = {
        model = "anthropic/claude-opus-4-8";
      };
      oracle = {
        model = "anthropic/claude-opus-4-8";
      };
      momus = {
        model = "anthropic/claude-opus-4-8";
      };
      explore = {
        model = "openai/gpt-5.4-mini-fast";
      };
      librarian = {
        model = "openai/gpt-5.4-mini-fast";
      };
    };

    categories = {
      visual-engineering = {
        model = "anthropic/claude-sonnet-4-6";
      };
      ultrabrain = {
        model = "anthropic/claude-opus-4-8";
        variant = "max";
      };
      deep = {
        model = "anthropic/claude-opus-4-8";
        variant = "max";
      };
      quick = {
        model = "openai/gpt-5.4-mini-fast";
      };
      writing = {
        model = "anthropic/claude-sonnet-4-6";
      };
    };
  };

  xdg.configFile."opencode/dcp.jsonc".text = builtins.toJSON {
    "$schema" =
      "https://raw.githubusercontent.com/Opencode-DCP/opencode-dynamic-context-pruning/master/dcp.schema.json";
    compress = {
      maxContextLimit = 300000;
    };
  };
}
