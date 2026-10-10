{
  name = "step-5-preview";
  upstream = "openai/step-5-preview-free";
  alias = null;
  metered = false;
  inputCostPerToken = 0.0;
  outputCostPerToken = 0.0;
  cacheReadInputTokenCost = 0.0;
  maxInputTokens = 1000000;
  maxOutputTokens = 65536;
  reasoningEffortLevels = [
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
