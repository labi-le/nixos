{ lib, pkgs }:

let
  keybindingsYml = pkgs.writeText "keybindings.yml" (
    builtins.toJSON {
      "app.stt.toggle" = "Alt+S";
    }
  );

  lspJson = pkgs.writeText "lsp.json" (
    builtins.toJSON {
      servers = {
        nixd = {
          command = "${pkgs.nixd}/bin/nixd";
          args = [ ];
          fileTypes = [ ".nix" ];
        };
        gopls = {
          command =
            (pkgs.writeShellScriptBin "gopls" ''
              export PATH=${lib.makeBinPath [ pkgs.go ]}:$PATH
              exec ${pkgs.gopls}/bin/gopls "$@"
            '')
            + "/bin/gopls";
          args = [ ];
          fileTypes = [ ".go" ];
        };
        biome = {
          command = "${pkgs.biome}/bin/biome";
          args = [ "lsp-proxy" ];
          fileTypes = [
            ".ts"
            ".tsx"
            ".js"
            ".jsx"
            ".mjs"
            ".cjs"
            ".mts"
            ".cts"
            ".json"
            ".jsonc"
            ".vue"
            ".astro"
            ".svelte"
            ".css"
            ".graphql"
            ".gql"
            ".html"
          ];
        };
        phpactor = {
          command = "${pkgs.phpactor}/bin/phpactor";
          args = [ "language-server" ];
          fileTypes = [ ".php" ];
        };
      };
    }
  );
in
{
  inherit keybindingsYml lspJson;
}
