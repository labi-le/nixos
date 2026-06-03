{ pkgs
, lib
, osConfig
, ...
}:

let
  aigateProvider = import ./aigate.nix;
  wrappers = import ./wrappers.nix { inherit pkgs lib osConfig; };
in

{
  imports = [
    ./packages.nix
    ./agents.nix
    ./integrations.nix
  ];

  programs.opencode = {
    enable = true;
    package = wrappers.opencodeWrapped;
    extraPackages = [ pkgs.rtk ];

    tui = {
      theme = lib.mkForce "opencode";
    };

    settings = {
      default_agent = "orchestrator";
      compaction = {
        auto = true;
        tail_turns = 14;
      };
      tool_output = {
        max_lines = 120;
        max_bytes = 12288;
      };
      provider = {
        litellm = {
          npm = "@ai-sdk/openai-compatible";
          name = "LiteLLM";
          options = {
            baseURL = "https://llm.labile.cc/v1";
            apiKey = "{env:LITELLM_MASTER_KEY}";
          };
          models = {
            "research-free" = {
              name = "research-free";
            };
          };
        };
        pollinations = {
          npm = "@ai-sdk/openai-compatible";
          name = "Pollinations";
          options = {
            baseURL = "https://gen.pollinations.ai/v1";
            apiKey = "{env:LITELLM_POLLINATIONS_API_KEY}";
          };
          models = {
            "openai" = { name = "openai"; };
            "gpt-5.5" = { name = "gpt-5.5"; };
            "claude-opus-4.8" = { name = "claude-opus-4.8"; };
            "deepseek" = { name = "deepseek"; };
            "gemini-3.5-flash" = { name = "gemini-3.5-flash"; };
            "gemini-large" = { name = "gemini-large"; };
            "llama-maverick" = { name = "llama-maverick"; };
            "mistral-4" = { name = "mistral-4"; };
            "qwen-coder" = { name = "qwen-coder"; };
            "grok-4.3" = { name = "grok-4.3"; };
            "kimi-k2.6" = { name = "kimi-k2.6"; };
            "nova" = { name = "nova"; };
          };
        };
        aigate = aigateProvider;
      };
    };
  };
}
