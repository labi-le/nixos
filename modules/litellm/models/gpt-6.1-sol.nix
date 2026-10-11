{
  name = "gpt-6.1-sol";
  provider = "chatgpt";
  upstream = "chatgpt/gpt-6.1-sol";
  retries = 2;
  inputCostPerToken = 2.0e-6;
  outputCostPerToken = 1.0e-5;
  cacheReadInputTokenCost = 1.0e-7;
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
