{ pkgs
, lib
, osConfig
}:

{
  rtkSource = pkgs.fetchFromGitHub {
    owner = "rtk-ai";
    repo = "rtk";
    tag = "v0.40.0";
    hash = "sha256-xWHIOZRpSyyOPQe/db9dxoODcnheBlpXrnKET010vVg=";
  };

  opencodeWrapped = pkgs.writeShellScriptBin "opencode" ''
    ${lib.optionalString (osConfig.age.secrets ? opencode-litellm-master-key) ''
      . "${osConfig.age.secrets.opencode-litellm-master-key.path}"
      export LITELLM_MASTER_KEY
      export LITELLM_POLLINATIONS_API_KEY
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

  opencodeMcpChromeDevtools = pkgs.writeShellScriptBin "opencode-mcp-chrome-devtools" ''
    export PATH="${
      lib.makeBinPath [
        pkgs.nodejs
      ]
    }:$PATH"
    exec npx -y chrome-devtools-mcp@latest "$@"
  '';
}
