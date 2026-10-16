{
  name = "longcat-2.5-preview-free";
  provider = "opencode-go";
  upstream = "openai/longcat-2.5-preview-free";
  metered = false;
  offPeakPricing = null;
  maxInputTokens = 1000000;
  maxOutputTokens = 131072;
  reasoningEffortLevels = [
    "minimal"
    "low"
    "medium"
    "high"
    "xhigh"
    "max"
  ];
  supportsVision = false;
  supportsFunctionCalling = true;
}
