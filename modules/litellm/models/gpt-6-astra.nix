{
  name = "gpt-6-astra";
  provider = "chatgpt";
  upstream = "chatgpt/gpt-6-astra";
  retries = 2;
  inputCostPerToken = 1.0e-5;
  outputCostPerToken = 5.0e-5;
  cacheReadInputTokenCost = 1.0e-6;
  maxInputTokens = 922000;
  maxOutputTokens = 128000;
  reasoningEffortLevels = [
    "low"
    "medium"
    "high"
    "xhigh"
    "max"
  ];
  supportsVision = true;
  supportsFunctionCalling = true;
}
