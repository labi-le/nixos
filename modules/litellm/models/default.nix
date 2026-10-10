{ lib }:

let
  poolSize = 4;
  apiBase = "https://opencode.ai/zen/go/v1";

  groups = [
    (import ./deepseek-v4.1-flash.nix)
    (import ./step-5-preview.nix)
  ];

  sessionIdOf =
    index:
    let
      hex = builtins.hashString "sha256" "opencode-go session ${toString index}";
    in
    lib.concatStrings [
      (builtins.substring 0 8 hex)
      "-"
      (builtins.substring 8 4 hex)
      "-"
      (builtins.substring 12 4 hex)
      "-"
      (builtins.substring 16 4 hex)
      "-"
      (builtins.substring 20 12 hex)
    ];

  deployment = group: index: {
    model_name = group.name;
    model_info = {
      opencode_usage_metered = group.metered;
      max_input_tokens = group.maxInputTokens;
      max_output_tokens = group.maxOutputTokens;
      supports_reasoning = group.reasoningEffortLevels != [ ];
      reasoning_effort_levels = group.reasoningEffortLevels;
      supports_vision = group.supportsVision;
      supports_function_calling = group.supportsFunctionCalling;
    };
    litellm_params = {
      model = group.upstream;
      api_base = apiBase;
      api_key = "os.environ/LITELLM_OPENCODE_GO_KEY_${toString (index + 1)}";
      extra_headers = {
        "x-opencode-session" = sessionIdOf (index + 1);
      };
      timeout = 900;
      stream_timeout = 180;
      max_retries = 0;
      input_cost_per_token = group.inputCostPerToken;
      output_cost_per_token = group.outputCostPerToken;
      cache_read_input_token_cost = group.cacheReadInputTokenCost;
    };
  };
in
{
  inherit poolSize;

  modelList = lib.concatMap (
    group: lib.imap0 (index: _: deployment group index) (lib.range 1 poolSize)
  ) groups;

  modelGroupAlias = lib.listToAttrs (
    map (group: {
      name = group.alias;
      value = group.name;
    }) (lib.filter (group: group.alias != null) groups)
  );
}
