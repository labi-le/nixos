{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.jcode.spaceBunny;

  models = [
    {
      id = "space-bunny-free";
      reasoning = true;
      reasoning_effort = "high";
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

        `supports_reasoning_effort = true` is the provider-level switch that
        lets jcode carry a reasoning effort for this endpoint at all; it is
        what replaces the "Reasoning effort is not supported by the current
        model/profile" refusal, and that message names this exact key as its
        escape hatch. The interactive ladder stays gated on
        `provider.available_efforts()` and remains unavailable here, so set a
        level with `/effort <level>` instead of the Alt+arrow stepper.
      '';
    };

    profileName = lib.mkOption {
      type = lib.types.strMatching "[A-Za-z0-9_-]+";
      default = "opencode-go-bunny";
      description = "jcode provider profile name for the declared bunny model.";
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
      models = models;
    };
  };
}
