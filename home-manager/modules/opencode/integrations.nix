{
  pkgs,
  lib,
  osConfig,
  ...
}:

let
  wrappers = import ./wrappers.nix { inherit pkgs lib osConfig; };
  systemPromptOverride = pkgs.writeText "system-prompt-override.ts" ''
    import type { Plugin } from "@opencode-ai/plugin"

    const DEFAULT_PREFIX = "You are OpenCode, You and the user share the same workspace and collaborate to achieve the user's goals."
    const DEFAULT_REPLACEMENT = [
      "You are OpenCode.",
      "Work with the user on software engineering tasks in the current workspace.",
      "Be accurate, concise, and pragmatic.",
      "Use tools when needed, avoid unnecessary output, and follow project instructions.",
    ].join("\n")

    const ENV_MARKER = "\nYou are powered by the model named "

    export default (async () => ({
      "experimental.chat.system.transform": async (_input, output) => {
        if (!Array.isArray(output.system) || output.system.length === 0) return
        const header = output.system[0]
        if (typeof header !== "string" || !header.startsWith(DEFAULT_PREFIX)) return

        const envIndex = header.indexOf(ENV_MARKER)
        if (envIndex === -1) {
          output.system[0] = DEFAULT_REPLACEMENT
          return
        }

        output.system[0] = DEFAULT_REPLACEMENT + header.slice(envIndex)
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
      "opencode-claude-auth@latest"
      "opencode-agent-skills@git+https://github.com/labi-le/agent-skills.git"
      "oh-my-opencode-slim@latest"
      "superpowers@git+https://github.com/obra/superpowers.git"
    ];
    mcp = {
      context7 = {
        type = "remote";
        url = "https://mcp.context7.com/mcp";
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

  xdg.configFile."opencode/plugins/system-prompt-override.ts".source = systemPromptOverride;
  xdg.configFile."opencode/plugins/rtk.ts".source = "${wrappers.rtkSource}/hooks/opencode/rtk.ts";

  xdg.configFile."opencode/oh-my-opencode-slim.json".source = ./providers/aigate-orchestrator.json;
}
