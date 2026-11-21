local M = {}

M.defaults = {
  recent_token_budget = 24000,
  chars_per_token = 4,
  tool_result_cap = 2000,
  tool_result_head_ratio = 0.6,
  tool_argument_cap = 500,
  tool_call_cap = 2000,
  max_frames = 40,
  renderer = "snapcompact-render",
  render_timeout_ms = 60000,
  image_size = 1568,
  font = "8x13",
  fallback_font = "silver",
  variant = "bw",
  columns = 1,
}

local IMAGE_PLACEHOLDER = "[image]"
local DIM_ON, DIM_OFF = "\14", "\15"

local FONTS = {
  ["5x8"] = true,
  ["8x8"] = true,
  ["6x12"] = true,
  ["8x13"] = true,
  silver = true,
}

local VARIANTS = { bw = true, sent = true }

local function parse_bounded(value, low, high)
  local number = tonumber(value)
  if not number or number ~= math.floor(number) or number < low or number > high then
    return nil
  end
  return math.floor(number)
end

function M.parse_args(args)
  local opts = {}
  for _, word in ipairs(args or {}) do
    local key, value = word:match("^([%w_]+)=(.*)$")
    if not key then
      return nil, "expected key=value, got " .. word
    end
    if key == "frames" or key == "max_frames" then
      local frames = parse_bounded(value, 1, 100)
      if not frames then
        return nil, "frames must be an integer from 1 to 100"
      end
      opts.max_frames = frames
    elseif key == "font" then
      if not FONTS[value] then
        return nil, "font must be 5x8, 8x8, 6x12, 8x13 or silver"
      end
      opts.font = value
    elseif key == "size" then
      local size = parse_bounded(value, 512, 4096)
      if not size then
        return nil, "size must be an integer from 512 to 4096"
      end
      opts.image_size = size
    elseif key == "columns" then
      local columns = parse_bounded(value, 1, 2)
      if not columns then
        return nil, "columns must be 1 or 2"
      end
      opts.columns = columns
    elseif key == "variant" then
      if not VARIANTS[value] then
        return nil, "variant must be bw or sent"
      end
      opts.variant = value
    else
      return nil, "unknown option " .. key
    end
  end
  return opts
end

local function option(opts, key)
  local value = opts and opts[key]
  if value == nil then
    return M.defaults[key]
  end
  return value
end

local function is_null(value)
  return value == nil or value == maki.NIL
end

local function text_of(value)
  if is_null(value) then
    return nil
  end
  local kind = type(value)
  if kind == "string" then
    return value
  end
  if kind == "number" or kind == "boolean" then
    return tostring(value)
  end
  return nil
end

local function is_continuation(byte)
  return byte ~= nil and byte >= 128 and byte < 192
end

local function cut_head(text, length)
  local index = math.min(length, #text)
  while index > 0 and is_continuation(text:byte(index + 1)) do
    index = index - 1
  end
  return text:sub(1, index)
end

local function cut_tail(text, length)
  local index = math.max(1, #text - length + 1)
  while index <= #text and is_continuation(text:byte(index)) do
    index = index + 1
  end
  return text:sub(index)
end

function M.cap(text, limit, head_ratio)
  if type(text) ~= "string" or #text <= limit then
    return text
  end
  local ratio = head_ratio or 1
  local head = math.floor(limit * ratio)
  local tail = limit - head
  local marker = "\n[... " .. (#text - head - tail) .. " chars omitted ...]\n"
  return cut_head(text, head) .. marker .. cut_tail(text, tail)
end

local function sorted_keys(target)
  local keys = {}
  for key in pairs(target) do
    if not is_null(key) then
      keys[#keys + 1] = key
    end
  end
  table.sort(keys, function(a, b)
    return tostring(a) < tostring(b)
  end)
  return keys
end

function M.stringify(value, depth)
  depth = depth or 0
  local text = text_of(value)
  if text then
    return text
  end
  if type(value) ~= "table" then
    return "<" .. type(value) .. ">"
  end
  if depth >= 3 then
    return "{...}"
  end
  local parts = {}
  for _, key in ipairs(sorted_keys(value)) do
    parts[#parts + 1] = tostring(key) .. ": " .. M.stringify(value[key], depth + 1)
  end
  if #parts == 0 then
    return "{}"
  end
  return "{" .. table.concat(parts, ", ") .. "}"
end

function M.content_text(content)
  if type(content) ~= "table" then
    return text_of(content) or ""
  end
  if content.type ~= nil then
    return M.content_text({ content })
  end
  local parts = {}
  for _, block in ipairs(content) do
    local kind = type(block) == "table" and block.type or nil
    if kind == "text" then
      parts[#parts + 1] = text_of(block.text) or ""
    elseif kind == "image" then
      parts[#parts + 1] = IMAGE_PLACEHOLDER
    elseif type(block) == "string" then
      parts[#parts + 1] = block
    end
  end
  return table.concat(parts, "\n")
end

local function block_chars(block)
  if type(block) ~= "table" then
    return 0
  end
  local kind = block.type
  if kind == "text" then
    return #(text_of(block.text) or "")
  elseif kind == "thinking" or kind == "redacted_thinking" then
    return 0
  elseif kind == "tool_use" then
    return #M.stringify(block.input) + 32
  elseif kind == "tool_result" then
    return #M.content_text(block.content)
  elseif kind == "image" then
    return 1600
  end
  return 32
end

function M.message_chars(message)
  if type(message) ~= "table" then
    return 0
  end
  local total = 0
  if type(message.content) == "table" then
    for _, block in ipairs(message.content) do
      total = total + block_chars(block)
    end
  elseif type(message.content) == "string" then
    total = #message.content
  end
  if type(message.display_text) == "string" then
    total = total + #message.display_text
  end
  return total
end

function M.message_cost(message, chars_per_token)
  local divisor = chars_per_token or M.defaults.chars_per_token
  return math.max(1, math.ceil(M.message_chars(message) / divisor))
end

function M.tool_pair_spans(messages)
  local by_id = {}
  local spans = {}
  for index, message in ipairs(messages) do
    if type(message) == "table" and type(message.content) == "table" then
      for _, block in ipairs(message.content) do
        if type(block) == "table" then
          if block.type == "tool_use" and type(block.id) == "string" then
            local span = { use = index }
            by_id[block.id] = span
            spans[#spans + 1] = span
          elseif block.type == "tool_result" and type(block.tool_use_id) == "string" then
            local span = by_id[block.tool_use_id]
            if span and not span.result then
              span.result = index
            end
          end
        end
      end
    end
  end
  return spans
end

local function carries_tool_result(message)
  if type(message) ~= "table" or type(message.content) ~= "table" then
    return false
  end
  for _, block in ipairs(message.content) do
    if type(block) == "table" and block.type == "tool_result" then
      return true
    end
  end
  return false
end

function M.is_safe_start(messages, index)
  local message = messages[index]
  if type(message) ~= "table" or message.role ~= "user" then
    return false
  end
  if carries_tool_result(message) then
    return false
  end
  return message.kind == nil or message.kind == "turn"
end

local function boundary_broken(spans, cut)
  for _, span in ipairs(spans) do
    if span.use < cut and span.result and span.result >= cut then
      return true
    end
  end
  return false
end

function M.split(messages, budget, opts)
  if type(messages) ~= "table" then
    return {}, {}
  end
  local count = #messages
  if count == 0 then
    return {}, {}
  end
  local limit = budget or option(opts, "recent_token_budget")
  local divisor = option(opts, "chars_per_token")
  local total, cut, fallback = 0, nil, nil
  for index = count, 1, -1 do
    total = total + M.message_cost(messages[index], divisor)
    if M.is_safe_start(messages, index) then
      if total <= limit then
        cut = index
      else
        if not fallback then
          fallback = index
        end
        break
      end
    end
  end
  cut = cut or fallback or (count + 1)
  local spans = M.tool_pair_spans(messages)
  while cut <= count and boundary_broken(spans, cut) do
    cut = cut + 1
  end
  local archive, recent = {}, {}
  for index = 1, cut - 1 do
    archive[#archive + 1] = messages[index]
  end
  for index = cut, count do
    recent[#recent + 1] = messages[index]
  end
  return archive, recent
end

function M.tool_names(messages)
  local names = {}
  for _, message in ipairs(messages) do
    if type(message) == "table" and type(message.content) == "table" then
      for _, block in ipairs(message.content) do
        if type(block) == "table" and block.type == "tool_use" and type(block.id) == "string" then
          names[block.id] = tostring(block.name or "?")
        end
      end
    end
  end
  return names
end

function M.render_block(block, names, opts)
  if type(block) ~= "table" then
    return nil
  end
  local kind = block.type
  if kind == "text" then
    local text = text_of(block.text)
    if not text or text == "" then
      return nil
    end
    return text
  end
  if kind == "tool_use" then
    local lines = { "[tool call: " .. tostring(block.name or "?") .. "]" }
    local argument_cap = option(opts, "tool_argument_cap")
    local input = block.input
    if type(input) == "table" then
      for _, key in ipairs(sorted_keys(input)) do
        lines[#lines + 1] = "  " .. tostring(key) .. ": " .. M.cap(M.stringify(input[key]), argument_cap, 1)
      end
    elseif type(input) == "string" and input ~= "" then
      lines[#lines + 1] = "  " .. M.cap(input, argument_cap, 1)
    end
    return M.cap(table.concat(lines, "\n"), option(opts, "tool_call_cap"), 1)
  end
  if kind == "tool_result" then
    local name = names[block.tool_use_id] or tostring(block.tool_use_id or "?")
    local header = "[tool result: " .. name .. (block.is_error and " (error)" or "") .. "]"
    local body = M.cap(
      M.content_text(block.content),
      option(opts, "tool_result_cap"),
      option(opts, "tool_result_head_ratio")
    )
    if body == "" then
      return header
    end
    if option(opts, "dim") then
      body = DIM_ON .. body .. DIM_OFF
    end
    return header .. "\n" .. body
  end
  if kind == "image" then
    return IMAGE_PLACEHOLDER
  end
  return nil
end

function M.serialize(messages, opts)
  if type(messages) ~= "table" then
    return ""
  end
  local names = M.tool_names(messages)
  local out = {}
  for index, message in ipairs(messages) do
    local parts = {}
    if type(message) == "table" and type(message.content) == "table" then
      for _, block in ipairs(message.content) do
        local rendered = M.render_block(block, names, opts)
        if rendered and rendered ~= "" then
          parts[#parts + 1] = rendered
        end
      end
    end
    if #parts > 0 then
      out[#out + 1] = "--- " .. index .. " " .. tostring(message.role or "?") .. " ---"
      out[#out + 1] = table.concat(parts, "\n")
    end
  end
  return table.concat(out, "\n\n")
end

function M.reflow(text)
  local out, buffer = {}, {}
  local function flush()
    if #buffer > 0 then
      out[#out + 1] = table.concat(buffer, " ")
      buffer = {}
    end
  end
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    local body = line:gsub("^%s+", ""):gsub("%s+$", "")
    if body == "" then
      flush()
    elseif body:match("^%-%-%- %d+ [%w_]+ %-%-%-$") then
      flush()
      out[#out + 1] = body
    else
      buffer[#buffer + 1] = body
    end
  end
  flush()
  return table.concat(out, "\n")
end

function M.lead_text(info)
  local frames = info.frame_count .. (info.frame_count == 1 and " frame" or " frames")
  local messages = info.recent_count .. (info.recent_count == 1 and " message" or " messages")
  local lines = {
    "The earlier part of this conversation was archived by /snapcompact.",
    "It is attached to this message as "
      .. frames
      .. " of rendered text (PNG images). Read those images to recover what happened: decisions, file paths, commands, tool results and errors.",
    "Plain-text copy: " .. info.archive_path,
    "Read that file with the read tool, using offset and limit, when an image is missing, unreadable, or its text looks cut.",
  }
  if info.truncated then
    lines[#lines + 1] = "The archive did not fit the frame budget, so the images hold the oldest pages and the newest page only; the skipped middle is in the plain-text copy."
  end
  lines[#lines + 1] = "The last " .. messages .. " follow this message unchanged."
  lines[#lines + 1] = "If the archived part held a todo list, rebuild it with todo_write before you continue."
  return table.concat(lines, "\n")
end

function M.build(opts)
  local frames = opts.frames or {}
  local content = {
    {
      type = "text",
      text = M.lead_text({
        archive_path = opts.archive_path,
        frame_count = #frames,
        recent_count = opts.recent_count or #(opts.recent or {}),
        truncated = opts.truncated,
      }),
    },
  }
  for _, frame in ipairs(frames) do
    content[#content + 1] = {
      type = "image",
      source = {
        type = "base64",
        media_type = "image/png",
        data = frame.data,
      },
    }
  end
  local messages = {}

  messages[1] = { role = "user", content = content }
  for _, message in ipairs(opts.recent or {}) do
    messages[#messages + 1] = maki.deepcopy(message)
  end
  local document = opts.document or {}
  local built = { messages = messages, focus = true }
  for _, key in ipairs({ "facts", "model", "mode", "thinking", "fast", "title" }) do
    local value = document[key]
    if not is_null(value) then
      if type(value) == "table" then
        built[key] = maki.deepcopy(value)
      else
        built[key] = value
      end
    end
  end
  return built
end

function M.render_request(text, opts)
  return {
    text = text,
    font = option(opts, "font"),
    fallback_font = option(opts, "fallback_font"),
    size = option(opts, "image_size"),
    variant = option(opts, "variant"),
    columns = option(opts, "columns"),
    max_frames = option(opts, "max_frames"),
  }
end

function M.timestamp()
  local now = os.time()
  if type(os.date) == "function" then
    return os.date("!%Y%m%dT%H%M%SZ", now)
  end
  return tostring(now)
end

function M.work_dir(session_id)
  local base, err = maki.env.state_dir()
  if not base then
    return nil, err
  end
  return maki.fs.joinpath(base, "snapcompact", tostring(session_id) .. "-" .. M.timestamp())
end

local function output_tail(stream)
  local text = type(stream) == "table" and table.concat(stream, "\n") or text_of(stream) or ""
  text = text:gsub("%s+$", "")
  if text == "" then
    return ""
  end
  return ": " .. M.cap(text, 400, 0.5)
end

function M.render(text, work_dir, opts)
  local frames_dir = maki.fs.joinpath(work_dir, "frames")
  local req_path = maki.fs.joinpath(work_dir, "req.json")
  local ok, mkdir_err = maki.fs.mkdir(frames_dir, { parents = true })
  if not ok then
    return nil, "cannot create " .. frames_dir .. " (" .. tostring(mkdir_err) .. ")"
  end
  local encoded, encode_err = maki.json.encode(M.render_request(text, opts))
  if not encoded then
    return nil, "cannot encode the renderer request (" .. tostring(encode_err) .. ")"
  end
  local written, write_err = maki.fs.write(req_path, encoded)
  if not written then
    return nil, "cannot write " .. req_path .. " (" .. tostring(write_err) .. ")"
  end
  local renderer = option(opts, "renderer")
  local job, job_err = maki.fn.jobstart({ renderer, req_path, frames_dir })
  if not job then
    return nil, renderer .. " is not runnable (" .. tostring(job_err) .. ")"
  end
  local timeout = option(opts, "render_timeout_ms")
  local result, wait_err = maki.fn.jobwait(job, timeout)
  if not result then
    return nil, "the renderer did not finish within " .. math.floor(timeout / 1000) .. "s (" .. tostring(wait_err) .. ")"
  end
  if result.exit_code ~= 0 then
    return nil, "the renderer exited with " .. tostring(result.exit_code) .. output_tail(result.stderr)
  end
  local manifest_path = maki.fs.joinpath(frames_dir, "manifest.json")
  local raw, read_err = maki.fs.read(manifest_path)
  if not raw then
    return nil, "the renderer wrote no manifest (" .. tostring(read_err) .. ")"
  end
  local manifest, decode_err = maki.json.decode(raw)
  if type(manifest) ~= "table" then
    return nil, "the manifest is not valid JSON (" .. tostring(decode_err) .. ")"
  end
  local entries = manifest.frames
  if type(entries) ~= "table" or #entries == 0 then
    return nil, "the manifest lists no frames"
  end
  local frames = {}
  for index, entry in ipairs(entries) do
    if type(entry) ~= "table" or type(entry.file) ~= "string" then
      return nil, "manifest frame " .. index .. " has no file name"
    end
    local path = maki.fs.joinpath(frames_dir, entry.file)
    local bytes, bytes_err = maki.fs.read_bytes(path)
    if not bytes then
      return nil, "cannot read " .. entry.file .. " (" .. tostring(bytes_err) .. ")"
    end
    frames[#frames + 1] = {
      data = maki.base64.encode(bytes),
      width = entry.width,
      height = entry.height,
      chars = entry.chars,
    }
  end
  return { frames = frames, truncated = manifest.truncated == true, font = manifest.font }
end

function M.fail(message)
  maki.ui.flash(message)
  return nil
end

function M.run(opts)
  opts = opts or {}
  if opts.args then
    local parsed, parse_err = M.parse_args(opts.args)
    if not parsed then
      return M.fail("snapcompact: " .. tostring(parse_err))
    end
    for key, value in pairs(parsed) do
      opts[key] = value
    end
  end
  local session_id, current_err = maki.session.current()
  if not session_id then
    return M.fail("snapcompact: no current session (" .. tostring(current_err) .. ")")
  end
  local document, export_err = maki.session.export({ session = session_id })
  if not document then
    return M.fail("snapcompact: cannot read the session (" .. tostring(export_err) .. ")")
  end
  local messages = document.messages
  if type(messages) ~= "table" or #messages == 0 then
    return M.fail("snapcompact: the session has no messages to archive")
  end
  local archive, recent = M.split(messages, option(opts, "recent_token_budget"), opts)
  if #archive == 0 then
    return M.fail("snapcompact: nothing to archive, the whole transcript still fits the recent window")
  end
  local text = M.serialize(archive, opts)
  if text == "" then
    return M.fail("snapcompact: the archived turns have no readable content")
  end
  local render_opts = { dim = true }
  for key, value in pairs(opts) do
    render_opts[key] = value
  end
  local rendered_text = M.reflow(M.serialize(archive, render_opts))
  local work_dir, dir_err = M.work_dir(session_id)
  if not work_dir then
    return M.fail("snapcompact: cannot locate the state directory (" .. tostring(dir_err) .. ")")
  end
  local made, make_err = maki.fs.mkdir(work_dir, { parents = true })
  if not made then
    return M.fail("snapcompact: cannot create " .. work_dir .. " (" .. tostring(make_err) .. ")")
  end
  local archive_path = maki.fs.joinpath(work_dir, "archive.txt")
  local saved, save_err = maki.fs.write(archive_path, text)
  if not saved then
    return M.fail("snapcompact: cannot write the archive (" .. tostring(save_err) .. ")")
  end
  local rendered, render_err = M.render(rendered_text, work_dir, opts)
  if not rendered then
    return M.fail("snapcompact: " .. tostring(render_err) .. "; the archive is at " .. archive_path)
  end
  local built = M.build({
    document = document,
    recent = recent,
    frames = rendered.frames,
    archive_path = archive_path,
    truncated = rendered.truncated,
  })
  local new_id, new_err = maki.session.new(built)
  if not new_id then
    local reason
    if tostring(new_err):find("no interactive UI", 1, true) then
      reason = "no interactive UI to open the new session in"
    else
      reason = tostring(new_err)
    end
    return M.fail("snapcompact: the new session was not created (" .. reason .. "); the archive is at " .. archive_path)
  end
  local deleted, delete_err = maki.session.delete({ id = session_id })
  if not deleted then
    maki.ui.flash(
      "snapcompact: session "
        .. tostring(new_id)
        .. " is open, the old one is kept ("
        .. tostring(delete_err)
        .. "); archive at "
        .. archive_path
    )
    return new_id
  end
  maki.ui.flash(
    "snapcompact: "
      .. #rendered.frames
      .. (#rendered.frames == 1 and " frame, " or " frames, ")
      .. #recent
      .. (#recent == 1 and " recent turn" or " recent turns")
      .. "; archive at "
      .. archive_path
  )
  return new_id
end

function M.safe_run(opts)
  local ok, value = pcall(M.run, opts or {})
  if not ok then
    maki.ui.flash("snapcompact: " .. tostring(value))
    return nil
  end
  return value
end

function M.register()
  if not (maki.api and maki.api.register_command) then
    return
  end
  pcall(maki.api.register_command, {
    name = "/snapcompact",
    description = "Archive the older turns as images and continue in a fresh session",
    nargs = "*",
    handler = function(opts)
      M.safe_run({ args = opts and opts.fargs or {} })
    end,
  })
end

M.register()

return M
