{
  name = "step-5-preview";
  provider = "opencode-go";
  upstream = "openai/step-5-preview-free";
  metered = false;
  offPeakPricing = null;
  maxInputTokens = 1000000;
  maxOutputTokens = 65536;
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
