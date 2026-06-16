{
  pkgs,
  lib,
  osConfig,
  indexerPkg,
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
    # Live code indexer: start `index-repo --daemon` in the background for the
    # duration of this opencode session and reap it on exit. Guards:
    #   - CODE_INDEXER_ACTIVE: set once so nested opencode invocations (e.g.
    #     background subagents) don't each spawn their own watcher.
    #   - CODE_INDEXER_DISABLE / .no-code-index: opt-out switches.
    #   - only inside a git repo.
    # setsid puts the daemon in its own process group so `kill -TERM -PGID`
    # reaps the whole uv -> python tree (uv may not forward signals).
    _indexer_pid=""
    if [ -z "''${CODE_INDEXER_ACTIVE:-}" ] && [ -z "''${CODE_INDEXER_DISABLE:-}" ] && [ -d "$PWD/.git" ] && [ ! -e "$PWD/.no-code-index" ]; then
      export CODE_INDEXER_ACTIVE=1
      ${pkgs.util-linux}/bin/setsid ${indexerPkg}/bin/index-repo --daemon "$PWD" >"''${XDG_RUNTIME_DIR:-/tmp}/code-indexer.log" 2>&1 &
      _indexer_pid=$!
    fi
    _cleanup() { [ -n "$_indexer_pid" ] && kill -TERM -"$_indexer_pid" 2>/dev/null; }
    trap _cleanup EXIT INT TERM

    ${pkgs.opencode}/bin/opencode "$@"
    _status=$?
    _cleanup
    exit $_status
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
