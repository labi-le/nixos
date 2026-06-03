{
  id = "litellm";
  env = [ "LITELLM_MASTER_KEY" ];
  provider = {
    npm = "@ai-sdk/openai-compatible";
    name = "LiteLLM";
    options = {
      baseURL = "https://llm.labile.cc/v1";
      apiKey = "{env:LITELLM_MASTER_KEY}";
    };
    models = {
      "research-free" = {
        name = "research-free";
      };
    };
  };
}
