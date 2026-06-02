{ pkgs, ... }:

let
  pi = pkgs.writeShellScriptBin "pi" ''
    exec ${pkgs.nix}/bin/nix run github:numtide/llm-agents.nix#pi -- "$@"
  '';
in
{
  home.packages = [ pi ];

  home.file.".pi/agent/settings.json".text = builtins.toJSON {
    lastChangelogVersion = "0.78.0";
    defaultProvider = "llamacpp";
    defaultModel = "Qwen3.5-9B-Q8_0.gguf";
    # defaultModel = "Qwen3-Coder-30B-A3B-Instruct-Q3_K_M.gguf";
    npmCommand = [
      "${pkgs.nodejs}/bin/npm"
    ];
    packages = [
      "npm:pi-subagents"
      "npm:pi-web-access"
    ];
  };

  home.file.".pi/agent/models.json".text = builtins.toJSON {
    providers = {
      llamacpp = {
        baseUrl = "http://192.168.1.3:8080/v1";
        api = "openai-completions";
        apiKey = "local";
        compat = {
          supportsDeveloperRole = false;
          supportsReasoningEffort = false;
          supportsUsageInStreaming = false;
          maxTokensField = "max_tokens";
        };
        models = [
          {
            id = "Qwen3.5-9B-Q8_0.gguf";
            name = "Qwen3.5 Local";
            reasoning = false;
            contextWindow = 16384;
            maxTokens = 4096;
          }
          {
            id = "qwen2.5-coder-32b-instruct-q4_k_m.gguf";
            name = "Qwen2.5 Coder 32B Local";
            reasoning = false;
            contextWindow = 8192;
            maxTokens = 4096;
          }
        ];
      };
    };
  };
}
