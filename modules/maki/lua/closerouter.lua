local secret = require("secret")

local SECRET_PATH = "/run/agenix/opencode-litellm-master-key"
local SECRET_NAME = "LITELLM_CLOSEROUTER"

local MODELS = {
  { prefixes = { "deepseek/deepseek-v4-pro-0813" }, context_window = 1000000, supports_thinking = true },
  { prefixes = { "deepseek/deepseek-v4.1-flash" }, context_window = 1000000, supports_thinking = true, default = true },
  { prefixes = { "qwen/qwen3.8-flash" }, context_window = 1000000, supports_thinking = true },
  { prefixes = { "qwen/qwen3.8-max" }, context_window = 1000000, supports_thinking = true },
}

maki.provider.register({
  slug = "closerouter",
  display_name = "Closerouter",
  codec = "openai",
  family = "generic",
  base_url = "https://api.closerouter.dev/v1",
  default_model = "deepseek/deepseek-v4.1-flash",
  models = MODELS,
  auth = function()
    local key, err = secret.read(SECRET_PATH, SECRET_NAME)
    if not key then
      return nil, err
    end
    return { headers = { Authorization = "Bearer " .. key } }
  end,
})
