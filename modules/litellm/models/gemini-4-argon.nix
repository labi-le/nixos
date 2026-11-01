{
  name = "gemini-4-argon";
  provider = "byesu";
  upstream = "openai/gemini-4-argon";
  apiBase = "https://byesu.com/v1";
  apiKeyEnv = "os.environ/BYESU_API_KEY";
  retries = 0;
  # byesu bills per its own tariff and exposes no machine-readable price, so the
  # local spend ledger records zero rather than a guessed rate.
  inputCostPerToken = 0;
  outputCostPerToken = 0;
  cacheReadInputTokenCost = 0;
  maxInputTokens = 1048576;
  maxOutputTokens = 65536;
  reasoningEffortLevels = [
    "low"
    "medium"
    "high"
  ];
  supportsVision = true;
  supportsFunctionCalling = true;
}
