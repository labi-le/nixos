{
  name = "deepseek-v4.1-flash";
  upstream = "openai/deepseek-v4.1-flash";
  # Legacy name from the 2026-10-10 rename; drop it once every client asks for
  # `deepseek-v4.1-flash` instead.
  alias = "opencode-go-pool";
  metered = true;
  inputCostPerToken = 3.0e-7;
  outputCostPerToken = 1.2e-6;
  cacheReadInputTokenCost = 6.0e-9;
  offPeakPricing = {
    hours_utc = [
      "00:00-01:00"
      "04:00-06:00"
      "10:00-00:00"
    ];
    windows = [
      {
        weekdays = [
          "sat"
          "sun"
        ];
        hours_utc = "00:00-00:00";
      }
    ];
    input_cost_per_token = 1.5e-7;
    output_cost_per_token = 6.0e-7;
    cache_read_input_token_cost = 3.0e-9;
  };
  maxInputTokens = 1000000;
  maxOutputTokens = 384000;
  reasoningEffortLevels = [
    "none"
    "minimal"
    "low"
    "medium"
    "high"
    "xhigh"
    "max"
  ];
  supportsVision = true;
  supportsFunctionCalling = true;
}
