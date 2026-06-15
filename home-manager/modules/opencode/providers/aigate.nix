{
  id = "aigate";
  env = [ "LITELLM_AIGATE_API_KEY" ];
  provider = {
    npm = "@ai-sdk/openai-compatible";
    name = "AIGate";
    options = {
      baseURL = "https://api.aigate.shop/v1";
      apiKey = "{env:LITELLM_AIGATE_API_KEY}";
    };
    models = import ./aigate-models.nix;
  };
}