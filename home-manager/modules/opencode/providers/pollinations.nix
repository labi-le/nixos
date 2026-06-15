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
    models = import ./pollinations-models.nix;
  };
}
