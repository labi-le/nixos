{ pkgs
, lib
, osConfig
, ...
}:

let
  wrappers = import ./wrappers.nix { inherit pkgs lib osConfig; };
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
      opendataloader-pdf = {
        type = "local";
        command = [ "${wrappers.opencodeMcpOpendataloaderPdf}/bin/opencode-mcp-opendataloader-pdf" ];
      };
      playwright = {
        type = "local";
        command = [ "${wrappers.opencodeMcpPlaywright}/bin/opencode-mcp-playwright" "--isolated" "--headless" "--executable-path" "${pkgs.chromium}/bin/chromium" ];
      };
    }
    // lib.optionalAttrs (osConfig.age.secrets ? opencode-grafana-mcp) {
      grafana = {
        type = "local";
        command = [ "${wrappers.opencodeMcpGrafana}/bin/opencode-mcp-grafana" ];
      };
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

  xdg.configFile."opencode/plugins/rtk.ts".source = "${wrappers.rtkSource}/hooks/opencode/rtk.ts";
}
