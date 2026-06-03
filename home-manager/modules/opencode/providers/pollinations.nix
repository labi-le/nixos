{
  id = "pollinations";
  env = [ "LITELLM_POLLINATIONS_API_KEY" ];
  provider = {
    npm = "@ai-sdk/openai-compatible";
    name = "Pollinations";
    options = {
      baseURL = "https://gen.pollinations.ai/v1";
      apiKey = "{env:LITELLM_POLLINATIONS_API_KEY}";
    };
    models = {
      "openai" = { name = "openai"; };
      "gpt-5.5" = { name = "gpt-5.5"; };
      "claude-opus-4.8" = { name = "claude-opus-4.8"; };
      "deepseek" = { name = "deepseek"; };
      "gemini-3.5-flash" = { name = "gemini-3.5-flash"; };
      "gemini-large" = { name = "gemini-large"; };
      "llama-maverick" = { name = "llama-maverick"; };
      "mistral-4" = { name = "mistral-4"; };
      "qwen-coder" = { name = "qwen-coder"; };
      "grok-4.3" = { name = "grok-4.3"; };
      "kimi-k2.6" = { name = "kimi-k2.6"; };
      "nova" = { name = "nova"; };
    };
  };
}
