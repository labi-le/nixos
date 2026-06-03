{
  npm = "@ai-sdk/openai-compatible";
  name = "AIGate";
  options = {
    baseURL = "https://api.aigate.shop/v1";
    apiKey = "{env:AIGATE_API_KEY}";
  };
  models = {
    "anthropic/claude-opus-4.6" = { name = "anthropic/claude-opus-4.6"; };
    "anthropic/claude-opus-4.7" = { name = "anthropic/claude-opus-4.7"; };
    "anthropic/claude-sonnet-4.6" = { name = "anthropic/claude-sonnet-4.6"; };
    "deepseek/deepseek-v4-flash" = { name = "deepseek/deepseek-v4-flash"; };
    "deepseek/deepseek-v4-pro" = { name = "deepseek/deepseek-v4-pro"; };
    "google/gemini-3-flash-preview" = { name = "google/gemini-3-flash-preview"; };
    "google/gemini-3.1-flash-lite" = { name = "google/gemini-3.1-flash-lite"; };
    "google/gemini-3.1-pro-preview" = { name = "google/gemini-3.1-pro-preview"; };
    "google/gemini-3.5-flash" = { name = "google/gemini-3.5-flash"; };
    "google/gemma-4-26b-a4b-it" = { name = "google/gemma-4-26b-a4b-it"; };
    "google/gemma-4-31b-it" = { name = "google/gemma-4-31b-it"; };
    "minimax/minimax-m2.7" = { name = "minimax/minimax-m2.7"; };
    "minimax/minimax-m3" = { name = "minimax/minimax-m3"; };
    "moonshotai/kimi-k2.6" = { name = "moonshotai/kimi-k2.6"; };
    "openai/gpt-5.4" = { name = "openai/gpt-5.4"; };
    "openai/gpt-5.4-mini" = { name = "openai/gpt-5.4-mini"; };
    "openai/gpt-5.4-nano" = { name = "openai/gpt-5.4-nano"; };
    "openai/gpt-5.5" = { name = "openai/gpt-5.5"; };
    "qwen/qwen3.7-max" = { name = "qwen/qwen3.7-max"; };
    "x-ai/grok-4.1-fast" = { name = "x-ai/grok-4.1-fast"; };
    "x-ai/grok-4.3" = { name = "x-ai/grok-4.3"; };
    "x-ai/grok-build-0.1" = { name = "x-ai/grok-build-0.1"; };
    "xiaomi/mimo-v2.5" = { name = "xiaomi/mimo-v2.5"; };
    "xiaomi/mimo-v2.5-pro" = { name = "xiaomi/mimo-v2.5-pro"; };
    "z-ai/glm-5.1" = { name = "z-ai/glm-5.1"; };
  };
}
