{
  name = "gpt-6-luna";
  provider = "chatgpt";
  upstream = "chatgpt/gpt-6-luna";
  retries = 2;
  inputCostPerToken = 1.0e-7;
  outputCostPerToken = 5.0e-7;
  cacheReadInputTokenCost = 1.0e-8;
  maxInputTokens = 872000;
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
