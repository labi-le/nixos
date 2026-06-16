{
  pkgs,
  lib,
  osConfig,
  providerDefs ? [ ],
}:

let
  providerEnv = lib.unique (lib.concatMap (item: item.env or [ ]) providerDefs);
  exportProviderEnv = lib.concatMapStringsSep "\n" (name: "      export ${name}") providerEnv;
in

{
  rtkSource = pkgs.fetchFromGitHub {
    owner = "rtk-ai";
    repo = "rtk";
    tag = "v0.40.0";
    hash = "sha256-xWHIOZRpSyyOPQe/db9dxoODcnheBlpXrnKET010vVg=";
  };

  opencodeWrapped = pkgs.writeShellScriptBin "opencode" ''
    export OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true
    ${lib.optionalString (osConfig.age.secrets ? opencode-litellm-master-key) ''
            . "${osConfig.age.secrets.opencode-litellm-master-key.path}"
      ${exportProviderEnv}
    ''}
    exec ${pkgs.opencode}/bin/opencode "$@"
  '';

  # opencodeMcpOpendataloaderPdf = pkgs.writeShellScriptBin "opencode-mcp-opendataloader-pdf" ''
  #   export JAVA_HOME="${pkgs.jre}"
  #   export PATH="${
  #     lib.makeBinPath [
  #       pkgs.jre
  #       pkgs.uv
  #     ]
  #   }:$PATH"
  #   exec ${pkgs.uv}/bin/uvx opendataloader-pdf-mcp
  # '';

}
