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
    models = {
      "claude-opus-4-8" = { name = "claude-opus-4-8"; };
      "claude-opus-4-7" = { name = "claude-opus-4-7"; };
      "claude-fable-5" = { name = "claude-fable-5"; };
      "claude-sonnet-4-6" = { name = "claude-sonnet-4-6"; };
      "claude-opus-4-6" = { name = "claude-opus-4-6"; };
      "claude-haiku-4-5-20251001" = { name = "claude-haiku-4-5-20251001"; };
    };
  };
}
