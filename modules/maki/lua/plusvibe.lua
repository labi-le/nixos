local secret = require("secret")

local SECRET_PATH = "/run/agenix/plusvibe-env"
local SECRET_NAME = "PLUSVIBE_API_KEY"

local MODELS = {
  { prefixes = { "claude-opus-5.5" }, context_window = 1000000, supports_thinking = true },
  { prefixes = { "claude-sonnet-5.5" }, context_window = 1000000, supports_thinking = true },
  { prefixes = { "claude-haiku-5.5" }, context_window = 1000000, supports_thinking = true, default = true },
  { prefixes = { "gpt-6.2-sol" }, context_window = 1050000, supports_thinking = true },
  { prefixes = { "google/gemini-4-argon" }, context_window = 1000000, supports_thinking = true },
  { prefixes = { "google/gemini-3.8-flash" }, context_window = 1000000, supports_thinking = true },
  { prefixes = { "deepseek-v4.1-flash" }, context_window = 900000, supports_thinking = true },
  { prefixes = { "moonshotai/kimi-k3" }, context_window = 1048576, supports_thinking = true },
  { prefixes = { "z-ai/glm-5.4" }, context_window = 1048000, supports_thinking = true },
}

maki.provider.register({
  slug = "plusvibe",
  display_name = "PlusVibe",
  codec = "openai",
  family = "generic",
  base_url = "https://plusvibeapi.ru/v1",
  default_model = "claude-haiku-5.5",
  models = MODELS,
  auth = function()
    local key, err = secret.read(SECRET_PATH, SECRET_NAME)
    if not key then
      return nil, err
    end
    return { headers = { Authorization = "Bearer " .. key } }
  end,
})
