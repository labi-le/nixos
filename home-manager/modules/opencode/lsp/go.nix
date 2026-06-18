{ pkgs, lib, ... }:

# gopls is a self-contained binary, but at runtime it shells out to `go` to
# build the package graph. Outside a `nix develop dev#go` shell `go` is not on
# PATH, so gopls starts but produces no diagnostics. Wrap it so the Go
# toolchain is always reachable regardless of how opencode was launched.
let
  gopls = pkgs.writeShellScriptBin "gopls" ''
    export PATH=${lib.makeBinPath [ pkgs.go ]}:$PATH
    exec ${pkgs.gopls}/bin/gopls "$@"
  '';
in
{
  programs.opencode.settings.lsp.gopls = {
    command = [ "${gopls}/bin/gopls" ];
    extensions = [ ".go" ];
  };
}
