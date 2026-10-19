local secret = require("secret")

local SECRET_PATH = "/run/agenix/byesu-env"
local SECRET_NAME = "BYESU_API_KEY"

local MODELS = {
  { prefixes = { "claude-opus-5-5" }, context_window = 1000000, supports_thinking = true },
  { prefixes = { "claude-sonnet-5-5" }, context_window = 1000000, supports_thinking = true },
  { prefixes = { "claude-haiku-5-5" }, context_window = 1000000, supports_thinking = true, default = true },
  { prefixes = { "gemini-3.8-flash" }, context_window = 1048576, supports_thinking = true },
  { prefixes = { "gemini-3.8-flash-high" }, context_window = 1048576, supports_thinking = true },
  { prefixes = { "gemini-3.1-pro-low" }, context_window = 1048576, supports_thinking = true },
  { prefixes = { "kimi-k3" }, context_window = 1048576, supports_thinking = true },
}

maki.provider.register({
  slug = "byesu",
  display_name = "byesu",
  codec = "openai",
  family = "generic",
  base_url = "https://byesu.com/v1",
  default_model = "claude-haiku-5-5",
  models = MODELS,
  auth = function()
    local key, err = secret.read(SECRET_PATH, SECRET_NAME)
    if not key then
      return nil, err
    end
    return { headers = { Authorization = "Bearer " .. key } }
  end,
})
