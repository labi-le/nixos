{
  pkgs,
  lib,
  osConfig,
  indexHook ? "",
  providerDefs ? [ ],
  variantConfigDirs ? { },
}:

let
  providerEnv = lib.unique (lib.concatMap (item: item.env or [ ]) providerDefs);
  exportProviderEnv = lib.concatMapStringsSep "\n" (name: "      export ${name}") providerEnv;
  mkOpencodeWrapper =
    {
      binName,
      configDir ? null,
    }:
    pkgs.writeShellScriptBin binName ''
      export PATH="${lib.makeBinPath [ pkgs.rtk ]}:$PATH"
      export OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true
      export OPENCODE_DISABLE_LSP_DOWNLOAD=true
      ${lib.optionalString (configDir != null) ''
            export OPENCODE_CONFIG_DIR="$HOME/.config/${configDir}"
      ''}
      ${lib.optionalString (osConfig.age.secrets ? opencode-litellm-master-key) ''
              . "${osConfig.age.secrets.opencode-litellm-master-key.path}"
        ${exportProviderEnv}
      ''}
      ${indexHook}
      ${pkgs.opencode}/bin/opencode "$@"
    '';
in

{
  rtkSource = pkgs.fetchFromGitHub {
    owner = "rtk-ai";
    repo = "rtk";
    tag = "v0.42.4";
    hash = "sha256-8nLJ5PVefXmoXQyw6HERfCP06C+l4I+7XLwKFNVNpew=";
  };

  opencodeWrapped = mkOpencodeWrapper {
    binName = "opencode";
    configDir = variantConfigDirs.claude;
  };
  opencodeGpt = mkOpencodeWrapper {
    binName = "opencode-gpt";
    configDir = variantConfigDirs.gpt;
  };

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
