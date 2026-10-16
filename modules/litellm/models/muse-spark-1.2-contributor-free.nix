{
  name = "muse-spark-1.2-contributor-free";
  provider = "zen-free";
  upstream = "openai/muse-spark-1.2-contributor-free";
  responses = true;
  maxInputTokens = 1048576;
  maxOutputTokens = 131072;
  reasoningEffortLevels = [
    "minimal"
    "low"
    "medium"
    "high"
    "xhigh"
  ];
  supportsVision = true;
  supportsFunctionCalling = true;
}
