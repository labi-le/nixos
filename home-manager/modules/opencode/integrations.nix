{
  pkgs,
  lib,
  osConfig,
  opencodeVariantConfigDirs,
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
  # Config JSON Schema (full config: agents, categories, git_master, ...):
  #   https://unpkg.com/oh-my-openagent@latest/dist/oh-my-opencode.schema.json
  #   canonical $id: https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/dev/assets/oh-my-opencode.schema.json
  mkAgentModels =
    modelsFile:
    let
      activeModels = builtins.fromJSON (builtins.readFile modelsFile);
    in
    {
      agents = activeModels.agents;
      categories = activeModels.categories;
    };
  claudeAgentModels = mkAgentModels ./anthropic-models.json;
  gptAgentModels = mkAgentModels ./openai-models.json;
  mkOhMyOpenAgentConfig = agentModels: {
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
  dcpConfig = {
    "$schema" =
      "https://raw.githubusercontent.com/Opencode-DCP/opencode-dynamic-context-pruning/master/dcp.schema.json";
    compress = {
      maxContextLimit = 200000;
    };
  };

  # Vendored skill collections. oh-my-openagent's `skill` tool only discovers
  # folder-skills under its scan dirs (here: ~/.config/opencode/skills via
  # programs.opencode.skills) plus its own hardcoded builtins -- it never sees
  # opencode core's embedded skills nor other plugins' skills. So to invoke the
  # superpowers + agent-skills plugin skills (and core's customize-opencode)
  # through that tool, we materialize each upstream skill as a folder-skill.
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
  ohMyOpenAgentSrc = pkgs.fetchFromGitHub {
    owner = "code-yeongyu";
    repo = "oh-my-openagent";
    rev = "ad4d2dfcc9049d764fb0ee737ca2f4558e0719a6";
    hash = "sha256-8gdNOgdnCvatfk1DsPQjNla1n64sy16w7s8l6DILsoU=";
  };
  # { <name> = "<dir>/<name>"; } for every <name>/SKILL.md under `dir`. readDir
  # (IFD) auto-tracks the upstream skill set, so an update-skills.sh rev bump
  # that adds/removes a skill needs no edit here.
  skillsFromDir =
    dir:
    lib.mapAttrs (name: _: "${dir}/${name}") (
      lib.filterAttrs (name: type: type == "directory" && builtins.pathExists "${dir}/${name}/SKILL.md") (
        builtins.readDir dir
      )
    );
  vendoredPluginSkills =
    skillsFromDir "${superpowersSrc}/skills"
    // skillsFromDir "${agentSkillsSrc}/skills"
    // skillsFromDir "${ohMyOpenAgentSrc}/packages/skills-loader-core/src/features/builtin-skills"
    // skillsFromDir "${ohMyOpenAgentSrc}/packages/shared-skills/skills"
    // skillsFromDir "${ohMyOpenAgentSrc}/packages/omo-codex/plugin/skills"
    // skillsFromDir "${ohMyOpenAgentSrc}/packages/omo-codex/plugin/components/ulw-loop/skills"
    // skillsFromDir "${ohMyOpenAgentSrc}/.agents/skills"
    // skillsFromDir "${ohMyOpenAgentSrc}/.opencode/skills";
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

  programs.opencode.skills = vendoredPluginSkills // {
    # opencode core's only built-in skill, embedded in the binary (no upstream
    # repo). Refresh after an opencode upgrade with:
    #   scripts/extract-customize-opencode-skill.py
    customize-opencode = "${./skills/customize-opencode}";

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
  xdg.configFile."${opencodeVariantConfigDirs.claude}/plugins/rtk.ts".source =
    "${wrappers.rtkSource}/hooks/opencode/rtk.ts";
  xdg.configFile."${opencodeVariantConfigDirs.gpt}/plugins/rtk.ts".source =
    "${wrappers.rtkSource}/hooks/opencode/rtk.ts";

  xdg.configFile."opencode/oh-my-openagent.jsonc" = {
    force = true;
    text = builtins.toJSON (mkOhMyOpenAgentConfig claudeAgentModels);
  };

  xdg.configFile."${opencodeVariantConfigDirs.claude}/oh-my-openagent.jsonc" = {
    force = true;
    text = builtins.toJSON (mkOhMyOpenAgentConfig claudeAgentModels);
  };

  xdg.configFile."${opencodeVariantConfigDirs.gpt}/oh-my-openagent.jsonc" = {
    force = true;
    text = builtins.toJSON (mkOhMyOpenAgentConfig gptAgentModels);
  };

  xdg.configFile."opencode/dcp.jsonc".text = builtins.toJSON dcpConfig;
  xdg.configFile."${opencodeVariantConfigDirs.claude}/dcp.jsonc".text = builtins.toJSON dcpConfig;
  xdg.configFile."${opencodeVariantConfigDirs.gpt}/dcp.jsonc".text = builtins.toJSON dcpConfig;

}
