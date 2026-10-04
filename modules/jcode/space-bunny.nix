{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.jcode.spaceBunny;

  effortLevels = [
    "low"
    "medium"
    "high"
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

        `supports_reasoning_effort = true` is *not* sufficient on its own.
        Measured 2026-10-05 in the real TUI on the bunny route, with a private
        daemon socket and the real store config: the status bar starts at the
        declared `high`, `/effort high` succeeds ("Reasoning effort → High"),
        but bare `/effort` and `Alt+Left`/`Alt+Right` print "Reasoning effort
        not available for this provider." That message is a different one from
        the "not supported by the current model/profile" text, which names
        this flag as its escape hatch, so the flag removes the refusal with
        that wording and nothing else: the interactive ladder is still gated
        on `provider.available_efforts()` being non-empty, and nothing
        declarable in this module populates it. Setting `model_catalog = true`
        did not help - the endpoint's `/models` payload publishes no effort
        metadata, so the catalog contributes no levels either. `allow_provider_pinning`
        was also tried and changed nothing about the ladder.
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
        Effort the profile starts at, and the level jcode puts on the wire
        until /effort changes it. The enum is narrow on purpose and covers
        only the levels jcode actually transmits to an OpenAI-compatible
        endpoint: `low`, `medium`, `high`, `max`. `minimal` and `xhigh` parse
        as valid efforts but are dropped before the request is built, so the
        body carries no `reasoning_effort` at all and the endpoint applies
        its own default, and `none`, `swarm` and `swarm-deep` are either
        dropped the same way or rejected by the endpoint with HTTP 400.
        `/effort <level>` sets it even though the interactive ladder is
        unavailable; Alt+Left/Alt+Right do not.
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
