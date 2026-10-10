{
  name = "deepseek-v4.1-flash";
  upstream = "openai/deepseek-v4.1-flash";
  alias = "opencode-go-pool";
  metered = true;
  inputCostPerToken = 3.0e-7;
  outputCostPerToken = 1.2e-6;
  cacheReadInputTokenCost = 6.0e-9;
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
