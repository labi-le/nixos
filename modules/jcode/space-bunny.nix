{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.jcode.spaceBunny;

  effortLevels = [
    "minimal"
    "low"
    "medium"
    "high"
    "xhigh"
    "max"
  ];

  models = [
    {
      id = "space-bunny-free";
      reasoning = true;
      reasoning_effort = cfg.defaultEffort;
      context_window = 1048576;
      input = [
        "text"
        "image"
      ];
    }
  ];
in
{
  options.jcode.spaceBunny = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Declare OpenCode Go's space-bunny-free model with its real capabilities.
        The provider's /models catalog publishes no reasoning or context
        metadata, so jcode otherwise treats the model as non-reasoning and
        offers no /effort ladder. This profile carries the models.dev values:
        1M context, text and image input, adjustable effort with `max` as the
        ceiling.

        `supports_reasoning_effort = true` is what unlocks the ladder at all:
        without it jcode refuses /effort and Alt+left/right with "Reasoning
        effort is not supported by the current model/profile". It is a
        provider-level switch, not a per-model one, so it cannot be inferred
        from the model's `reasoning = true`. `disable_reasoning_heuristics`
        stops jcode from adding `reasoning_effort` on a model-name guess for
        endpoints that reject it.
      '';
    };

    profileName = lib.mkOption {
      type = lib.types.strMatching "[A-Za-z0-9_-]+";
      default = "opencode-go-bunny";
      description = "jcode provider profile name for the declared bunny model.";
    };

    defaultEffort = lib.mkOption {
      type = lib.types.enum effortLevels;
      default = "high";
      description = ''
        Effort the profile starts at, and the level jcode sends on the wire
        until /effort changes it. The endpoint answers 400 for `none`,
        `swarm` and `swarm-deep`, so the enum covers only the values it
        accepts; picking one here means every request carries a usable effort
        instead of failing validation upstream.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    jcode.extensions.providers.${cfg.profileName} = {
      type = "openai-compatible";
      base_url = "https://opencode.ai/zen/go/v1";
      api_key_env = "OPENCODE_GO_API_KEY";
      env_file = "opencode-go.env";
      default_model = "space-bunny-free";
      supports_reasoning_effort = true;
      disable_reasoning_heuristics = true;
      models = models;
    };
  };
}
