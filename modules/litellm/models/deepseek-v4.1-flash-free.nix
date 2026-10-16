{
  name = "deepseek-v4.1-flash-free";
  provider = "zen-free";
  upstream = "openai/deepseek-v4.1-flash-free";
  maxInputTokens = 200000;
  maxOutputTokens = 32000;
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
