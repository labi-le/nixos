{
  pkgs,
  lib,
  osConfig,
  indexHook ? "",
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
    tag = "v0.42.4";
    hash = "sha256-8nLJ5PVefXmoXQyw6HERfCP06C+l4I+7XLwKFNVNpew=";
  };

  opencodeWrapped = pkgs.writeShellScriptBin "opencode" ''
    export OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true
    export OPENCODE_DISABLE_LSP_DOWNLOAD=true
    ${lib.optionalString (osConfig.age.secrets ? opencode-litellm-master-key) ''
            . "${osConfig.age.secrets.opencode-litellm-master-key.path}"
      ${exportProviderEnv}
    ''}
    ${indexHook}
    ${pkgs.opencode}/bin/opencode "$@"
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
