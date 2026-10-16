{
  name = "beam-free";
  provider = "opencode-go";
  upstream = "openai/beam-free";
  metered = false;
  offPeakPricing = null;
  maxInputTokens = 1048576;
  maxOutputTokens = 131072;
  reasoningEffortLevels = [
    "low"
    "medium"
    "high"
    "xhigh"
    "max"
  ];
  supportsVision = false;
  supportsFunctionCalling = true;
}
