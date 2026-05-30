{ pkgs
, lib
, osConfig
, ...
}:

let
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
      };
    };
  };
}
