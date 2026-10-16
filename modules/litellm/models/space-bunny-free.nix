{
  name = "space-bunny-free";
  provider = "zen-free";
  upstream = "openai/space-bunny-free";
  maxInputTokens = 1048576;
  maxOutputTokens = 524288;
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
