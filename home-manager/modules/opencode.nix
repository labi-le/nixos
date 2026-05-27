{ pkgs
, lib
, osConfig
, ...
}:

let
  opencodeMcpGrafana = pkgs.writeShellScriptBin "opencode-mcp-grafana" ''
    ${lib.optionalString (osConfig.age.secrets ? opencode-grafana-mcp) ''
      set -a
      . "${osConfig.age.secrets.opencode-grafana-mcp.path}"
      set +a
    ''}
    exec ${pkgs.uv}/bin/uvx mcp-grafana
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
    package = pkgs.opencode;

    tui = {
      theme = lib.mkForce "opencode";
    };

    settings = {
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
      } // lib.optionalAttrs (osConfig.age.secrets ? opencode-grafana-mcp) {
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
