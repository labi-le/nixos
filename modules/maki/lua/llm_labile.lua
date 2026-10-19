local parse = require("maki.provider_parse")

local MODELS_PATH = "/model/info"
local CHAT_MODE = "chat"
local RESPONSES_MODE = "responses"

local function parse_row(entry)
  if type(entry) ~= "table" or type(entry.model_name) ~= "string" then
    return nil
  end
  local info = entry.model_info
  if type(info) ~= "table" then
    return nil
  end
  local mode = info.mode
  if type(mode) == "string" and mode ~= CHAT_MODE and mode ~= RESPONSES_MODE then
    return nil
  end

  local window = parse.as_u32(info.max_input_tokens)
  maki.log.debug(string.format("llm-labile %s context_window=%s", entry.model_name, tostring(window)))

  return {
    id = entry.model_name,
    context_window = window,
    max_output_tokens = parse.as_u32(info.max_output_tokens),
    pricing = parse.pricing(
      info.input_cost_per_token,
      info.output_cost_per_token,
      info.cache_creation_input_token_cost,
      info.cache_read_input_token_cost
    ),
    supports_thinking = parse.as_bool(info.supports_reasoning),
    supports_vision = info.supports_vision == true,
  }
end

maki.provider.register({
  slug = "llm-labile-cc",
  display_name = "llm.labile.cc",
  codec = "openai",
  base_url = "https://llm.labile.cc/v1",
  api_key_env = "LLM_LABILE_CC_API_KEY",
  default_model = "deepseek-v4.1-flash",
  context_window = 200000,
  list_models = function(ctx)
    local body, err = ctx.get_json(MODELS_PATH)
    if err then
      return nil, err
    end
    return parse.models(body, parse_row)
  end,
})
