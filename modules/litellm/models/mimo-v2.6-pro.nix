{
  name = "mimo-v2.6-pro";
  provider = "xiaomi-mimo";
  upstream = "xiaomi_mimo/mimo-v2.6-pro";
  apiBase = "https://token-plan-sgp.xiaomimimo.com/v1";
  apiKeyEnv = "os.environ/XIAOMI_MIMO_API_KEY";
  inputCostPerToken = 4.35e-7;
  outputCostPerToken = 8.7e-7;
  cacheReadInputTokenCost = 3.6e-9;
  maxInputTokens = 1048576;
  maxOutputTokens = 131072;
  reasoningEffortLevels = [
    "none"
    "low"
    "medium"
    "high"
  ];
  supportsVision = true;
  supportsFunctionCalling = true;
}
