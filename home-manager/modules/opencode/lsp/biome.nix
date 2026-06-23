{ pkgs, ... }:

{
  home.packages = [ pkgs.biome ];

  programs.opencode.settings.lsp.biome = {
    command = [ "${pkgs.biome}/bin/biome" "lsp-proxy" ];
    extensions = [
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
}
