{
  name = "muse-spark-1.3-contributor-free";
  provider = "zen-free";
  upstream = "openai/muse-spark-1.3-contributor-free";
  responses = true;
  maxInputTokens = 1048576;
  maxOutputTokens = 131072;
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
