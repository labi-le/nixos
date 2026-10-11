{
  name = "deepseek-v4.1-flash";
  provider = "opencode-go";
  upstream = "openai/deepseek-v4.1-flash";
  metered = true;
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
