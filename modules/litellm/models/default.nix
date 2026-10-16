{ lib }:

let
  poolSize = 4;
  apiBase = "https://opencode.ai/zen/go/v1";
  prices = builtins.fromJSON (builtins.readFile ./prices.json);

  declaredGroups = [
    (import ./beam-free.nix)
    (import ./deepseek-v4.1-flash.nix)
    (import ./longcat-2.5-preview-free.nix)
    (import ./step-5-preview.nix)
    (import ./deepseek-v4.1-flash-free.nix)
    (import ./space-bunny-free.nix)
    (import ./muse-spark-1.2-contributor-free.nix)
    (import ./muse-spark-1.3-contributor-free.nix)
    (import ./gpt-6-astra.nix)
    (import ./gpt-6-luna.nix)
    (import ./gpt-6.1-sol.nix)
  ];

  zenGroupNames = map (group: group.name) (
    builtins.filter (group: group.provider == "opencode-go") declaredGroups
  );

  priceOf =
    group:
    if prices.models ? ${group.name} then
      prices.models.${group.name}
    else
      throw "modules/litellm/models/prices.json carries no entry for ${group.name}; sync-prices.py owns that file";

  withPrices =
    group:
    if group.provider != "opencode-go" then
      group
    else
      let
        price = priceOf group;
      in
      group
      // {
        inputCostPerToken = price.input;
        outputCostPerToken = price.output;
        cacheReadInputTokenCost = price.cacheRead;
        offPeakPricing =
          if price.offPeak == null then
            null
          else if group.offPeakPricing == null then
            throw "${group.name} carries off-peak rates in prices.json but no off-peak windows in its group file"
          else
            group.offPeakPricing
            // {
              input_cost_per_token = price.offPeak.input;
              output_cost_per_token = price.offPeak.output;
              cache_read_input_token_cost = price.offPeak.cacheRead;
            };
      };

  groups = map withPrices declaredGroups;

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

  metadata = group: {
    max_input_tokens = group.maxInputTokens;
    max_output_tokens = group.maxOutputTokens;
    supports_reasoning = group.reasoningEffortLevels != [ ];
    reasoning_effort_levels = group.reasoningEffortLevels;
    supports_vision = group.supportsVision;
    supports_function_calling = group.supportsFunctionCalling;
    cooldown_time = 0;
  };

  poolDeployment = group: index: {
    model_name = group.name;
    model_info = metadata group // {
      opencode_usage_metered = group.metered;
    }
    // lib.optionalAttrs (group.offPeakPricing != null) {
      off_peak_pricing = group.offPeakPricing;
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
      num_retries = 0;
      input_cost_per_token = group.inputCostPerToken;
      output_cost_per_token = group.outputCostPerToken;
      cache_read_input_token_cost = group.cacheReadInputTokenCost;
    };
  };

  zenFreeDeployment = group: {
    model_name = group.name;
    model_info = metadata group
    // {
      opencode_usage_metered = false;
      zen_free_fingerprint = true;
    }
    // lib.optionalAttrs (group.responses or false) {
      mode = "responses";
    };
    litellm_params = {
      model = group.upstream;
      api_base = "https://opencode.ai/zen/v1";
      api_key = "public";
      timeout = 900;
      stream_timeout = 180;
      max_retries = 2;
      num_retries = 2;
      input_cost_per_token = 0.0;
      output_cost_per_token = 0.0;
      cache_read_input_token_cost = 0.0;
    };
  };

  chatgptDeployment = group: {
    model_name = group.name;
    model_info = metadata group // {
      mode = "responses";
    };
    litellm_params = {
      model = group.upstream;
      timeout = 900;
      stream_timeout = 180;
      max_retries = group.retries;
      num_retries = group.retries;
      input_cost_per_token = group.inputCostPerToken;
      output_cost_per_token = group.outputCostPerToken;
      cache_read_input_token_cost = group.cacheReadInputTokenCost;
    };
  };

  deploymentsOf =
    group:
    if group.provider == "opencode-go" then
      lib.imap0 (index: _: poolDeployment group index) (lib.range 1 poolSize)
    else if group.provider == "zen-free" then
      [ (zenFreeDeployment group) ]
    else
      [ (chatgptDeployment group) ];
in
{
  inherit poolSize;
  inherit groups;
  inherit zenGroupNames;

  modelList = lib.concatMap deploymentsOf groups;
}
