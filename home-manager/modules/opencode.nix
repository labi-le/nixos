{ pkgs, lib, ... }:

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
      plugin = [
        "opencode-gemini-auth@latest"
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
      };
    };
    skills = {
      desloppify = "${
        pkgs.fetchFromGitHub {
          owner = "peteromallet";
          repo = "desloppify";
          rev = "a084a7cbb4b47c83782b3160f8bd8f10151e789f";
          hash = "sha256-KVCt9loGSzsOaYSLNzpyUCi/TpCDQ4b6BxEydQTRNcA=";
        }
      }/docs";
      plantuml-rendering = "${
        pkgs.fetchFromGitHub {
          owner = "asolfre";
          repo = "plantuml-rendering-skill";
          rev = "5191edd2b30b8729a3ada1b61db381f3132d6764";
          hash = "sha256-SOkpdeAkC68unov70AseGrK3GB0FK/HdR9MxgsqaNr0=";
        }
      }";
    };
  };
}
