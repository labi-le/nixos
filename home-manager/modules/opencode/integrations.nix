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
  # anthropic-models.json provides the `agents` + `categories` sections of the
  # oh-my-openagent plugin config (merged into oh-my-openagent.jsonc below).
  # Config JSON Schema (full config: agents, categories, git_master, ...):
  #   https://unpkg.com/oh-my-openagent@latest/dist/oh-my-opencode.schema.json
  #   canonical $id: https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/dev/assets/oh-my-opencode.schema.json
  activeModels = builtins.fromJSON (builtins.readFile ./anthropic-models.json);
  agentModels = {
    agents = activeModels.agents;
    categories = activeModels.categories;
  };
in

{
  # chroma-gate opencode plugin + `chroma` MCP server are provided by the
  # index-repo home-manager module (services.index-repo.opencode.*); the plugin
  # source lives in that repo instead of being inlined here.
  services.index-repo.opencode = {
    chromaGate.enable = true;
    chromaMcp = {
      enable = true;
      host = "192.168.1.2";
    };
  };

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
      # "opencode-agent-skills@git+https://github.com/labi-le/agent-skills.git"
      "oh-my-openagent@latest"
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
        rev = "25d22f864ad68cc447a4cb93aefde918aa4aec9f";
        hash = "sha256-FbmfhFaPs/SnSZdfNdErdIUHXt1FfBzErpPpLy8kdIc=";
      }
    }/skills/caveman";
  };

  xdg.configFile."opencode/plugins/rtk.ts".source = "${wrappers.rtkSource}/hooks/opencode/rtk.ts";

  xdg.configFile."opencode/oh-my-openagent.jsonc" = {
    force = true;
    text = builtins.toJSON {
      "$schema" =
        "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/dev/assets/oh-my-opencode.schema.json";
      team_mode = {
        enabled = true;
        max_parallel_members = 8;
        tmux_visualization = true;
      };
      background_task = {
        defaultConcurrency = 10;
      };

      git_master = {
        include_co_authored_by = false;
      };

      agents = agentModels.agents;
      categories = agentModels.categories;
    };
  };

  xdg.configFile."opencode/dcp.jsonc".text = builtins.toJSON {
    "$schema" =
      "https://raw.githubusercontent.com/Opencode-DCP/opencode-dynamic-context-pruning/master/dcp.schema.json";
    compress = {
      maxContextLimit = 200000;
    };
  };
}
