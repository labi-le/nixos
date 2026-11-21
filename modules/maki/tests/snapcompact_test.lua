local script = (arg and arg[0]) or "modules/maki/tests/snapcompact_test.lua"
local base = script:match("^(.*)[/\\][^/\\]*$") or "."
local module_path = base .. "/../lua/snapcompact.lua"

local env

local function reset()
  env = {
    current = "s1",
    document = nil,
    created = nil,
    deleted = {},
    files = {},
    flashes = {},
    manifest_raw = "{}",
    manifest = nil,
    manifest_error = nil,
    png = "\137PNG\r\n",
    png_missing = false,
    jobstart_id = 7,
    jobstart_error = nil,
    jobwait_result = { exit_code = 0, stdout = "", stderr = "" },
    jobwait_error = nil,
    new_id = "s2",
    new_error = nil,
    delete_error = nil,
    request = nil,
  }
end

local function deepcopy(value, seen)
  if type(value) ~= "table" then
    return value
  end
  seen = seen or {}
  if seen[value] then
    return seen[value]
  end
  local copy = {}
  seen[value] = copy
  for key, item in pairs(value) do
    copy[deepcopy(key, seen)] = deepcopy(item, seen)
  end
  local mt = getmetatable(value)
  if mt then
    setmetatable(copy, mt)
  end
  return copy
end

reset()

local registered = nil

maki = {
  NIL = nil,
  deepcopy = deepcopy,
  ui = {
    flash = function(message)
      env.flashes[#env.flashes + 1] = message
    end,
  },
  api = {
    register_command = function(spec)
      registered = spec
    end,
  },
  fs = {
    joinpath = function(...)
      local parts = { ... }
      return table.concat(parts, "/")
    end,
    mkdir = function()
      return true
    end,
    write = function(path, content)
      env.files[path] = content
      return true
    end,
    read = function(path)
      if env.files[path] ~= nil then
        return env.files[path]
      end
      if path:match("/manifest%.json$") then
        if env.manifest_raw == nil then
          return nil, "ENOENT"
        end
        return env.manifest_raw
      end
      return nil, "ENOENT"
    end,
    read_bytes = function()
      if env.png_missing then
        return nil, "ENOENT"
      end
      return env.png
    end,
  },
  base64 = {
    encode = function(data)
      return "BASE64:" .. tostring(data)
    end,
  },
  json = {
    encode = function(value)
      env.request = value
      return "{}"
    end,
    decode = function()
      if env.manifest_error then
        return nil, env.manifest_error
      end
      return env.manifest
    end,
  },
  fn = {
    jobstart = function()
      if env.jobstart_error then
        return nil, env.jobstart_error
      end
      return env.jobstart_id
    end,
    jobwait = function()
      if env.jobwait_error then
        return nil, env.jobwait_error
      end
      return env.jobwait_result
    end,
  },
  env = {
    state_dir = function()
      return "/state", nil
    end,
  },
  session = {
    current = function()
      if not env.current then
        return nil, "no interactive UI attached"
      end
      return env.current
    end,
    export = function()
      return env.document
    end,
    data_dir = function()
      return "/state/sessions/data/s1/plugin", nil
    end,
    new = function(document)
      if env.new_error then
        return nil, env.new_error
      end
      env.created = document
      return env.new_id, nil
    end,
    delete = function(opts)
      if env.delete_error then
        return nil, env.delete_error
      end
      env.deleted[#env.deleted + 1] = opts.id
      return true
    end,
  },
}

local snapcompact = assert(loadfile(module_path))()

local passed, failed = 0, 0

local function test(name, body)
  reset()
  local ok, err = pcall(body)
  if ok then
    passed = passed + 1
    print("ok   " .. name)
  else
    failed = failed + 1
    print("FAIL " .. name .. "\n     " .. tostring(err))
  end
end

local function check(condition, message)
  if not condition then
    error(message or "assertion failed", 2)
  end
end

local function turn(number)
  return { role = "user", kind = "turn", content = { { type = "text", text = "instruction " .. number } } }
end

local function call(number)
  return {
    role = "assistant",
    content = {
      { type = "text", text = "working " .. number },
      { type = "tool_use", id = "call_" .. number, name = "bash", input = { cmd = "ls " .. number } },
    },
  }
end

local function result(number)
  return {
    role = "user",
    content = { { type = "tool_result", tool_use_id = "call_" .. number, content = "output " .. number } },
  }
end

local function transcript(turns)
  local messages = {}
  for number = 1, turns do
    messages[#messages + 1] = turn(number)
    messages[#messages + 1] = call(number)
    messages[#messages + 1] = result(number)
  end
  return messages
end

local function valid_utf8(text)
  local index, length = 1, #text
  while index <= length do
    local byte = text:byte(index)
    local size
    if byte < 0x80 then
      size = 1
    elseif byte >= 0xC2 and byte <= 0xDF then
      size = 2
    elseif byte >= 0xE0 and byte <= 0xEF then
      size = 3
    elseif byte >= 0xF0 and byte <= 0xF4 then
      size = 4
    else
      return false
    end
    for offset = 1, size - 1 do
      local next_byte = text:byte(index + offset)
      if not next_byte or next_byte < 0x80 or next_byte > 0xBF then
        return false
      end
    end
    index = index + size
  end
  return true
end

local function ready(overrides)
  local messages = transcript(6)
  env.document = {
    model = "anthropic/claude",
    mode = "build",
    thinking = "adaptive",
    fast = false,
    title = "long session",
    facts = { date = "2026-11-21", cwd = "/home/labile/nix" },
    messages = messages,
  }
  env.manifest = {
    frames = {
      { file = "frame-000.png", width = 1568, height = 812, chars = 6000 },
      { file = "frame-001.png", width = 1568, height = 812, chars = 4000 },
    },
    truncated = false,
    font = "8x13",
  }
  for key, value in pairs(overrides or {}) do
    env[key] = value
  end
  return messages
end

test("registers the /snapcompact command", function()
  check(registered ~= nil, "command not registered")
  check(registered.name == "/snapcompact", "wrong command name: " .. tostring(registered.name))
  check(type(registered.handler) == "function", "handler missing")
end)

test("split never separates a tool call from its result", function()
  local messages = transcript(12)
  local archive, recent = snapcompact.split(messages, 60)
  check(#archive + #recent == #messages, "messages lost")
  for index = 1, #archive do
    check(archive[index] == messages[index], "archive not in order")
  end
  for index = 1, #recent do
    check(recent[index] == messages[#archive + index], "recent not in order")
  end
  check(#archive > 0, "nothing archived at a 60 token budget")
  check(#recent < #messages, "everything kept as recent")
  check(snapcompact.is_safe_start(recent, 1), "recent does not start at a turn boundary")
  local uses, results = {}, {}
  for _, message in ipairs(archive) do
    for _, block in ipairs(message.content) do
      if block.type == "tool_use" then
        uses[block.id] = true
      end
    end
  end
  for _, message in ipairs(recent) do
    for _, block in ipairs(message.content) do
      if block.type == "tool_result" then
        results[block.tool_use_id] = true
      end
    end
  end
  for id in pairs(uses) do
    check(not results[id], "tool call " .. id .. " was cut from its result")
  end
  local cost = 0
  for _, message in ipairs(recent) do
    cost = cost + snapcompact.message_cost(message)
  end
  check(cost <= 60, "recent window exceeded the budget: " .. cost)
end)

test("split keeps one oversized turn intact", function()
  local archive, recent = snapcompact.split(transcript(3), 1)
  check(#recent == 3, "expected the last turn only, got " .. #recent .. " messages")
  check(#archive == 6, "wrong archive size: " .. #archive)
  check(snapcompact.is_safe_start(recent, 1), "recent does not start at a turn boundary")
  local results = {}
  for _, message in ipairs(recent) do
    for _, block in ipairs(message.content) do
      if block.type == "tool_result" then
        results[block.tool_use_id] = true
      end
    end
  end
  check(results["call_3"], "last tool result lost")
  check(not results["call_2"], "an older tool result leaked into recent")
end)

test("split archives nothing when the transcript fits", function()
  local archive = snapcompact.split(transcript(1), 100000)
  check(#archive == 0, "expected an empty archive")
end)

test("serialize applies caps and skips thinking", function()
  local messages = {
    {
      role = "assistant",
      content = {
        { type = "thinking", thinking = "SECRETTHOUGHT" },
        { type = "redacted_thinking", data = "SECRETREDACTED" },
        { type = "tool_use", id = "c1", name = "read", input = { path = string.rep("p", 900) } },
      },
    },
    {
      role = "user",
      content = {
        { type = "tool_result", tool_use_id = "c1", content = string.rep("R", 6000) .. "TAILMARK" },
        { type = "image", source = { type = "base64", media_type = "image/png", data = "x" } },
      },
    },
  }
  local text = snapcompact.serialize(messages)
  check(not text:find("SECRETTHOUGHT", 1, true), "thinking leaked into the archive")
  check(not text:find("SECRETREDACTED", 1, true), "redacted thinking leaked into the archive")
  check(text:find("chars omitted", 1, true), "no truncation marker")
  check(text:find("TAILMARK", 1, true), "tail of a long tool result was dropped")
  check(text:find("[image]", 1, true), "image placeholder missing")
  check(text:find("[tool result: read]", 1, true), "tool result not named after its call")
  check(not text:find(string.rep("p", 600), 1, true), "tool argument value was not capped")
  check(not text:find(string.rep("R", 1300), 1, true), "tool result was not capped")
  check(#text < 3200, "serialized archive is too large: " .. #text)
  check(#text > 2000, "serialized archive lost the capped body: " .. #text)
end)

test("serialize caps a tool call as a whole", function()
  local input = {}
  for index = 1, 40 do
    input["key" .. index] = string.rep("v", 600)
  end
  local messages = {
    { role = "assistant", content = { { type = "tool_use", id = "c1", name = "bash", input = input } } },
  }
  local text = snapcompact.serialize(messages)
  check(#text < 2100, "tool call was not capped: " .. #text)
  check(text:find("chars omitted", 1, true), "no truncation marker on the tool call")
end)

test("caps do not split a multi-byte character", function()
  local cyrillic = string.rep("я", 3000)
  local capped = snapcompact.cap(cyrillic, 999, 0.6)
  check(#capped > 999, "cap lost the marker")
  check(valid_utf8(capped), "cap produced invalid UTF-8")
  local messages = {
    { role = "user", content = { { type = "tool_result", tool_use_id = "c9", content = cyrillic } } },
  }
  check(valid_utf8(snapcompact.serialize(messages)), "serialize produced invalid UTF-8")
end)

test("build produces the lead-in and the image blocks", function()
  local archive_path = "/state/sessions/data/s1/plugin/snapcompact/s1-20260101T000000Z/archive.txt"
  local recent = { turn(9), call(9), result(9) }
  local frames = {
    { data = "AAA", width = 1568, height = 812 },
    { data = "BBB", width = 1568, height = 812 },
  }
  local built = snapcompact.build({
    archive_path = archive_path,
    recent = recent,
    frames = frames,
    truncated = true,
    document = { model = "m", mode = "build", thinking = "adaptive", fast = true, title = "t" },
  })
  check(built.focus == true, "focus is not set")
  local lead = built.messages[1]
  check(lead.role == "user", "lead-in is not a user message")
  check(lead.content[1].type == "text", "lead-in text block missing")
  local text = lead.content[1].text
  check(text:find(archive_path, 1, true), "lead-in has no archive path")
  check(text:find("2 frames", 1, true), "lead-in has no frame count")
  check(text:find("3 messages", 1, true), "lead-in has no recent message count")
  check(text:find("todo_write", 1, true), "lead-in does not mention todo_write")
  check(text:find("skipped middle", 1, true), "lead-in does not say what truncation drops")
  check(#lead.content == 3, "expected one text block plus two images")
  for index = 2, 3 do
    local block = lead.content[index]
    check(block.type == "image", "block " .. index .. " is not an image")
    check(block.source.type == "base64", "image source type is wrong")
    check(block.source.media_type == "image/png", "image media type is wrong")
    check(block.source.data == frames[index - 1].data, "image data mismatch")
  end
  check(#built.messages == 4, "recent messages were not appended")
  check(built.messages[2].content[1].text == "instruction 9", "recent message changed")
  check(built.model == "m" and built.mode == "build" and built.thinking == "adaptive", "settings lost")
  check(built.fast == true and built.title == "t", "fast or title lost")
end)

test("build keeps array tags through deepcopy", function()
  local tag = { __maki_array_tag = true }
  local tagged = setmetatable({}, tag)
  local built = snapcompact.build({
    archive_path = "/tmp/archive.txt",
    recent = {},
    frames = {},
    document = { facts = { hints = tagged }, messages = {} },
  })
  check(getmetatable(built.facts.hints) == tag, "deepcopy dropped the array tag")
  check(built.facts.hints ~= tagged, "facts were not copied")
end)

test("run writes the archive and creates the follow-up session", function()
  ready()
  local id = snapcompact.safe_run({ recent_token_budget = 30 })
  check(id == "s2", "run returned " .. tostring(id))
  check(#env.flashes == 1, "expected one flash, got " .. #env.flashes)
  local built = env.created
  check(built ~= nil, "session.new was not called")
  local lead = built.messages[1].content[1].text
  local archive_path = lead:match("Plain%-text copy: (%S+)")
  check(archive_path ~= nil, "lead-in has no archive path")
  check(archive_path:match("^/state/snapcompact/s1%-%d+"), "unexpected work dir: " .. tostring(archive_path))
  check(archive_path:find("/sessions/data/", 1, true) == nil, "archive lives under the deleted session")
  check(archive_path:match("archive%.txt$"), "archive path does not end in archive.txt")
  check(env.files[archive_path] ~= nil, "archive.txt was not written")
  check(env.files[archive_path]:find("tool result", 1, true) ~= nil, "archive.txt has no tool results")
  check(#built.messages[1].content == 3, "expected the text block plus two frames")
  check(env.request ~= nil, "req.json was not built")
  check(env.request.text ~= env.files[archive_path], "request text is the pretty archive")
  check(env.request.text:find("\n\n", 1, true) == nil, "request text still has blank rows")
  check(env.request.text:find("\14", 1, true) ~= nil, "request text has no dim markers")
  check(env.files[archive_path]:find("\14", 1, true) == nil, "archive.txt has control characters")
  check(env.request.max_frames == 40 and env.request.size == 1568, "renderer request fields wrong")
  check(env.request.font == "8x13" and env.request.fallback_font == "silver", "renderer fonts wrong")
  check(#env.deleted == 1 and env.deleted[1] == "s1", "old session was not deleted")
end)

test("run keeps the old session when deletion fails", function()
  ready({ delete_error = "the session is busy" })
  local id = snapcompact.safe_run({ recent_token_budget = 30 })
  check(id == "s2", "run returned " .. tostring(id))
  check(#env.flashes == 1, "expected one flash")
  check(env.flashes[1]:find("kept", 1, true) ~= nil, "flash does not say the old session was kept")
  check(env.flashes[1]:find("the session is busy", 1, true) ~= nil, "flash hides the delete error")
end)

test("run reports an empty archive", function()
  ready({ document = { messages = transcript(1) } })
  snapcompact.safe_run({ recent_token_budget = 100000 })
  check(env.created == nil, "session.new was called with nothing to archive")
  check(#env.flashes == 1, "expected one flash")
  check(env.flashes[1]:find("nothing to archive", 1, true) ~= nil, "wrong flash: " .. tostring(env.flashes[1]))
end)

test("run reports a missing current session", function()
  ready({ current = false })
  snapcompact.safe_run({})
  check(env.created == nil, "session.new was called without a session")
  check(env.flashes[1]:find("no current session", 1, true) ~= nil, "wrong flash: " .. tostring(env.flashes[1]))
end)

test("run reports an export failure", function()
  ready({ document = false })
  snapcompact.safe_run({})
  check(env.created == nil, "session.new was called after an export failure")
  check(env.flashes[1]:find("cannot read the session", 1, true) ~= nil, "wrong flash: " .. tostring(env.flashes[1]))
end)

test("run reports a missing renderer", function()
  ready({ jobstart_error = "ENOENT" })
  snapcompact.safe_run({ recent_token_budget = 30 })
  check(env.created == nil, "session.new was called without frames")
  check(env.flashes[1]:find("not runnable", 1, true) ~= nil, "wrong flash: " .. tostring(env.flashes[1]))
  check(env.flashes[1]:find("archive.txt", 1, true) ~= nil, "flash does not point at the archive")
end)

test("run reports a renderer timeout", function()
  ready({ jobwait_error = "timeout" })
  snapcompact.safe_run({ recent_token_budget = 30 })
  check(env.created == nil, "session.new was called after a timeout")
  check(env.flashes[1]:find("did not finish", 1, true) ~= nil, "wrong flash: " .. tostring(env.flashes[1]))
end)

test("run reports a renderer exit code", function()
  ready({ jobwait_result = { exit_code = 2, stdout = "", stderr = "font table is missing\n" } })
  snapcompact.safe_run({ recent_token_budget = 30 })
  check(env.created == nil, "session.new was called after a renderer failure")
  check(env.flashes[1]:find("exited with 2", 1, true) ~= nil, "wrong flash: " .. tostring(env.flashes[1]))
  check(env.flashes[1]:find("font table is missing", 1, true) ~= nil, "flash hides the renderer stderr")
end)

test("run reports a broken manifest", function()
  ready({ manifest_error = "unexpected symbol" })
  snapcompact.safe_run({ recent_token_budget = 30 })
  check(env.created == nil, "session.new was called with a broken manifest")
  check(env.flashes[1]:find("manifest", 1, true) ~= nil, "wrong flash: " .. tostring(env.flashes[1]))
end)

test("run reports a manifest without frames", function()
  ready({ manifest = { frames = {}, truncated = false } })
  snapcompact.safe_run({ recent_token_budget = 30 })
  check(env.created == nil, "session.new was called without frames")
  check(env.flashes[1]:find("no frames", 1, true) ~= nil, "wrong flash: " .. tostring(env.flashes[1]))
end)

test("run reports an unreadable frame", function()
  ready({ png_missing = true })
  snapcompact.safe_run({ recent_token_budget = 30 })
  check(env.created == nil, "session.new was called with an unreadable frame")
  check(env.flashes[1]:find("cannot read", 1, true) ~= nil, "wrong flash: " .. tostring(env.flashes[1]))
end)

test("run reports a headless session.new failure", function()
  ready({ new_error = "no interactive UI attached" })
  snapcompact.safe_run({ recent_token_budget = 30 })
  check(#env.deleted == 0, "the old session was deleted without a replacement")
  check(env.flashes[1]:find("no interactive UI", 1, true) ~= nil, "wrong flash: " .. tostring(env.flashes[1]))
end)

test("run survives an exception from the runtime", function()
  env.session = nil
  snapcompact.safe_run({})
  check(#env.flashes == 1, "expected one flash")
  check(env.flashes[1]:find("snapcompact:", 1, true) == 1, "wrong flash: " .. tostring(env.flashes[1]))
end)

test("parse_args accepts the knobs", function()
  local opts = snapcompact.parse_args({ "frames=60", "font=6x12", "size=2048", "columns=2", "variant=sent" })
  check(opts ~= nil, "parse_args rejected valid arguments")
  check(opts.max_frames == 60 and opts.font == "6x12", "frames or font not applied")
  check(opts.image_size == 2048 and opts.columns == 2 and opts.variant == "sent", "size, columns or variant not applied")
end)

test("parse_args rejects bad input", function()
  local _, err = snapcompact.parse_args({ "frames=0" })
  check(err ~= nil and err:find("frames", 1, true), "frames=0 accepted")
  _, err = snapcompact.parse_args({ "font=comic" })
  check(err ~= nil and err:find("font", 1, true), "unknown font accepted")
  _, err = snapcompact.parse_args({ "nonsense" })
  check(err ~= nil and err:find("key=value", 1, true), "bare word accepted")
  _, err = snapcompact.parse_args({ "colour=red" })
  check(err ~= nil and err:find("unknown option", 1, true), "unknown key accepted")
end)

test("run passes arguments through to the renderer", function()
  ready()
  local id = snapcompact.safe_run({ recent_token_budget = 30, args = { "frames=7", "font=6x12" } })
  check(id == "s2", "run returned " .. tostring(id))
  check(env.request.max_frames == 7, "frames argument ignored")
  check(env.request.font == "6x12", "font argument ignored")
end)

test("run refuses a bad argument", function()
  ready()
  snapcompact.safe_run({ recent_token_budget = 30, args = { "frames=lots" } })
  check(env.created == nil, "session.new ran with a bad argument")
  check(env.flashes[1]:find("frames", 1, true) ~= nil, "wrong flash: " .. tostring(env.flashes[1]))
end)

test("reflow joins lines and keeps message headers", function()
  local text = "--- 1 user ---\nline one\n  line two\n\n\nparagraph\n--- 2 assistant ---\ncalled\nthe tool"
  local flowed = snapcompact.reflow(text)
  local lines = {}
  for line in flowed:gmatch("[^\n]+") do
    lines[#lines + 1] = line
  end
  check(#lines == 5, "expected 5 rows, got " .. #lines)
  check(lines[1] == "--- 1 user ---", "message header moved: " .. lines[1])
  check(lines[2] == "line one line two", "lines not joined: " .. lines[2])
  check(lines[3] == "paragraph", "blank row did not break the paragraph: " .. lines[3])
  check(lines[4] == "--- 2 assistant ---", "second header moved: " .. lines[4])
  check(lines[5] == "called the tool", "second paragraph wrong: " .. lines[5])
end)

test("reflow drops blank rows only", function()
  check(snapcompact.reflow("a\n\n\nb") == "a\nb", "blank rows survived")
  check(snapcompact.reflow("") == "", "empty text did not stay empty")
end)

test("dim markers wrap tool output only", function()
  local blocks = {
    { type = "tool_use", id = "c1", name = "bash", input = { cmd = "ls" } },
    { type = "tool_result", tool_use_id = "c1", content = { { type = "text", text = "output" } } },
  }
  local plain = { role = "user", content = blocks }
  local dim = snapcompact.serialize({ plain, plain }, { dim = true })
  check(dim:find("\14output\15", 1, true) ~= nil, "tool output is not dimmed")
  check(dim:find("\14ls", 1, true) == nil, "tool call arguments were dimmed")
  local undimmed = snapcompact.serialize({ plain }, {})
  check(undimmed:find("\14", 1, true) == nil, "dim markers leak without the flag")
end)

print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
