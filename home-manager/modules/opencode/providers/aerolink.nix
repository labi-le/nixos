{
  id = "aerolink";
  env = [ "LITELLM_AEROLINK_API_KEY" ];
  provider = {
    npm = "@ai-sdk/openai-compatible";
    name = "Aerolink";
    options = {
      baseURL = "https://capi.aerolink.lat/v1";
      apiKey = "{env:LITELLM_AEROLINK_API_KEY}";
    };
    models = import ./aerolink-models.nix;
  };
}
