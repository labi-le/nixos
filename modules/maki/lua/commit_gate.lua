local SUFFIX = "\n\nAdjust the command and run it again. Commit convention: the commit-style skill."
local MAX_SUBJECT = 70
local WORD = "[A-Za-z0-9][A-Za-z0-9._/-]*"
local EXEMPT = {
  ["--dry-run"] = true,
  ["--fixup"] = true,
  ["--squash"] = true,
  ["-C"] = true,
  ["--reuse-message"] = true,
  ["-c"] = true,
  ["--reedit-message"] = true,
}
local INDIRECT_FLAGS = {
  ["-F"] = true,
  ["--file"] = true,
  ["-t"] = true,
  ["--template"] = true,
}

local function deny(reason)
  return nil, "Blocked: " .. reason .. SUFFIX
end

local function trim(text)
  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function basename(token)
  return token:match("([^/]+)$") or token
end

local function lex(command)
  local commands, words = {}, {}
  local word, in_word, expanded = nil, false, false
  local index, length = 1, #command

  local function flush()
    if in_word then
      words[#words + 1] = { value = word or "", expanded = expanded }
    end
    word, in_word, expanded = nil, false, false
  end

  local function finish()
    flush()
    if #words > 0 then
      commands[#commands + 1] = words
    end
    words = {}
  end

  while index <= length do
    local char = command:sub(index, index)
    if char == "'" then
      in_word = true
      word = word or ""
      index = index + 1
      while index <= length and command:sub(index, index) ~= "'" do
        word = word .. command:sub(index, index)
        index = index + 1
      end
      index = index + 1
    elseif char == '"' then
      in_word = true
      word = word or ""
      index = index + 1
      while index <= length and command:sub(index, index) ~= '"' do
        local inner = command:sub(index, index)
        if inner == "\\" then
          word = word .. command:sub(index + 1, index + 1)
          index = index + 2
        else
          if inner == "$" or inner == "`" then
            expanded = true
          end
          word = word .. inner
          index = index + 1
        end
      end
      index = index + 1
    elseif char == "\\" then
      in_word = true
      word = (word or "") .. command:sub(index + 1, index + 1)
      index = index + 2
    elseif char == "\n" or char == ";" then
      finish()
      index = index + 1
    elseif char == "&" then
      if command:sub(index + 1, index + 1) == "&" then
        index = index + 1
      end
      finish()
      index = index + 1
    elseif char == "|" then
      if command:sub(index + 1, index + 1) == "|" then
        index = index + 1
      end
      finish()
      index = index + 1
    elseif char == "(" or char == ")" then
      finish()
      index = index + 1
    elseif char:match("%s") then
      flush()
      index = index + 1
    else
      if char == "$" or char == "`" then
        expanded = true
      end
      in_word = true
      word = (word or "") .. char
      index = index + 1
    end
  end

  finish()
  return commands
end

local function generated_subject(subject)
  local lower = subject:lower()
  for _, prefix in ipairs({ "merge", "revert", "fixup!", "squash!", "amend!" }) do
    if lower:sub(1, #prefix) == prefix then
      local after = lower:sub(#prefix + 1, #prefix + 1)
      if after == "" or not after:match("%a") then
        return true
      end
    end
  end
  return false
end

local function component_subject(subject)
  local patterns = {
    "^" .. WORD .. ": %S",
    "^" .. WORD .. " " .. WORD .. ": %S",
    "^" .. WORD .. " " .. WORD .. " " .. WORD .. ": %S",
  }
  for _, pattern in ipairs(patterns) do
    if subject:match(pattern) then
      return true
    end
  end
  return false
end

local function generated_trailer(text)
  if text:find("🤖", 1, true) then
    return "🤖"
  end
  for line in (text .. "\n"):gmatch("(.-)\n") do
    local lower = line:lower()
    if lower:match("^co%-authored%-by:") then
      return trim(line)
    end
    if lower:match("^generated with") then
      return trim(line)
    end
  end
  return nil
end

local function exempt(tokens)
  for _, token in ipairs(tokens) do
    local value = token.value
    if EXEMPT[value] or value:match("^%-%-fixup=") or value:match("^%-%-squash=") then
      return true
    end
  end
  return false
end

local function collect_messages(tokens)
  local messages, indirect = {}, nil
  local index = 1
  while index <= #tokens do
    local token = tokens[index]
    local value = token.value
    if value == "-m" or value == "--message" then
      if tokens[index + 1] then
        messages[#messages + 1] = tokens[index + 1]
      end
      index = index + 2
    elseif value:match("^%-%-message=") then
      messages[#messages + 1] = { value = value:sub(11), expanded = token.expanded }
      index = index + 1
    elseif value == "--edit" then
      indirect = "`--edit`, which hands the message to an editor"
      index = index + 1
    elseif INDIRECT_FLAGS[value] then
      indirect = "`" .. value .. "`"
      index = index + 2
    elseif value:match("^%-%-file=") or value:match("^%-%-template=") then
      indirect = "`" .. value .. "`"
      index = index + 1
    elseif value:match("^%-%-") then
      index = index + 1
    elseif value:sub(1, 1) == "-" then
      local cluster = value:sub(2)
      local message_at = cluster:find("m", 1, true)
      local edit_at = cluster:find("e", 1, true)
      if edit_at and (not message_at or edit_at < message_at) then
        indirect = "`" .. value .. "`, which hands the message to an editor"
      end
      if message_at then
        local attached = cluster:sub(message_at + 1)
        if attached ~= "" then
          messages[#messages + 1] = { value = attached, expanded = token.expanded }
        elseif tokens[index + 1] then
          messages[#messages + 1] = tokens[index + 1]
          index = index + 1
        end
      end
      index = index + 1
    else
      index = index + 1
    end
  end
  return messages, indirect
end

local function message_denial(message)
  local trimmed = trim(message.value)
  if message.expanded then
    return "the message is assembled by the shell, so what git would record cannot be read; pass the literal text"
  end
  if trimmed:find("\n", 1, true) then
    return "the message carries a body; it is one line only -- a decision the diff cannot show belongs in `docs/`"
  end
  if trimmed == "" then
    return "the subject is empty"
  end
  local subject = trimmed
  if generated_subject(subject) then
    return nil
  end
  if subject:match("^[A-Za-z]+%([^)]*%):") then
    return "the subject uses the conventional-commits `type(scope):` form; the prefix is a component -- the module, host or package the change belongs to (`maki:`, `nginx:`, `server:`)"
  end
  if not component_subject(subject) then
    return "the subject is not `component: what changed`, with at most three words before the colon"
  end
  local length = utf8.len(subject) or #subject
  if length > MAX_SUBJECT then
    return "the subject is " .. length .. " characters; 70 is the hard ceiling and the median belongs under 30"
  end
  if subject:sub(-1) == "." then
    return "the subject ends with a period"
  end
  local trailer = generated_trailer(trimmed)
  if trailer then
    return "the message carries a generated trailer (`" .. trailer .. "`)"
  end
  return nil
end

local function environment_override(words)
  for _, token in ipairs(words) do
    local name = token.value:match("^([A-Za-z_][A-Za-z0-9_]*)=")
    if
      name
      and (
        name == "EDITOR"
        or name == "VISUAL"
        or name == "SEQUENCE_EDITOR"
        or name == "GIT_EDITOR"
        or name == "GIT_VISUAL"
        or name == "GIT_SEQUENCE_EDITOR"
        or name:match("^GIT_CONFIG")
      )
    then
      return "an environment override (`" .. name .. "`)"
    end
  end
  return nil
end

local function config_override(configs)
  for _, config in ipairs(configs) do
    local lower = config:lower()
    if
      lower:find("core.editor=", 1, true)
      or lower:find("sequence.editor=", 1, true)
      or lower:find("commit.template=", 1, true)
    then
      local key = config:match("^([^=]+)") or config
      return "a config override (`" .. key .. "`)"
    end
  end
  return nil
end

local function commit_gate(words, global_configs, prefix)
  if exempt(words) then
    return nil
  end
  local indirect = environment_override(prefix) or config_override(global_configs)
  local messages, flag_indirect = collect_messages(words)
  indirect = indirect or flag_indirect
  if indirect then
    return deny(
      "the message would come from "
        .. indirect
        .. "; pass the literal text in a single `-m` so what git records can be read"
    )
  end
  if #messages == 0 then
    return deny(
      "the commit carries no `-m`, so the message would come from git's editor buffer -- a template, a hook or a prepared `COMMIT_EDITMSG` -- and cannot be read here; pass the literal text in a single `-m`"
    )
  end
  if #messages > 1 then
    return deny(
      "the message is split across repeated `-m` flags; pass a single `-m` holding one line"
    )
  end
  local reason = message_denial(messages[1])
  if reason then
    return deny(reason)
  end
  return nil
end

local MR_SOURCE_FLAGS = {
  "--fill",
  "--fill-first",
  "--fill-verbose",
  "--fill-commit-body",
  "--template",
  "--editor",
  "--recover",
  "--attach",
  "--web",
  "--body-file",
  "--description-file",
  "--title-file",
  "--signoff",
}

local function mr_source_flag(value)
  for _, flag in ipairs(MR_SOURCE_FLAGS) do
    if value == flag or value:sub(1, #flag + 1) == flag .. "=" then
      return true
    end
  end
  return false
end

local function mr_value(tokens, index, name)
  local token = tokens[index]
  local value = token.value
  if value == name then
    return tokens[index + 1], index + 2
  end
  if value:sub(1, #name + 1) == name .. "=" then
    return { value = value:sub(#name + 2), expanded = token.expanded }, index + 1
  end
  return nil, index
end

local function merge_request_gate(tool, subcommand, tokens)
  local creating = subcommand == "create" or subcommand == "new"
  if not creating then
    return nil
  end
  local title, description, source
  local index = 1
  while index <= #tokens do
    local value = tokens[index].value
    local found
    found, index = mr_value(tokens, index, "--title")
    if found then
      title = found
    else
      found, index = mr_value(tokens, index, "-t")
      if found then
        title = found
      else
        found, index = mr_value(tokens, index, "--body")
        if found then
          description = found
        else
          found, index = mr_value(tokens, index, "-b")
          if found then
            description = found
          else
            found, index = mr_value(tokens, index, "--description")
            if found then
              description = found
            else
              found, index = mr_value(tokens, index, "-d")
              if found then
                description = found
              elseif mr_source_flag(value) then
                source = value
                index = index + 1
              elseif value:match("^%-%a*[FT]%a*$") then
                source = value
                index = index + 1
              else
                index = index + 1
              end
            end
          end
        end
      end
    end
  end
  if source then
    return deny("MR text from a file, template, editor or generated source cannot be checked")
  end
  if not title then
    return deny("MR creation requires an explicit literal title and empty description")
  end
  if title.expanded then
    return deny("the MR title is assembled by the shell; pass literal text")
  end
  local trimmed = trim(title.value)
  if trimmed == "" or trimmed:find("\n", 1, true) then
    return deny("the MR title must be nonempty and one line")
  end
  if (utf8.len(trimmed) or #trimmed) > MAX_SUBJECT then
    return deny("the MR title exceeds 70 Unicode characters")
  end
  if not description then
    return deny("MR creation requires an explicit literal title and empty description")
  end
  if description.expanded then
    return deny("the MR description is assembled by the shell; pass literal text")
  end
  if description.value ~= "" then
    return deny("the MR description must be exactly empty")
  end
  return nil
end

local function first_command(words)
  local wrappers = {
    sudo = true,
    doas = true,
    env = true,
    command = true,
    nice = true,
    time = true,
    ionice = true,
    xargs = true,
    ssh = true,
  }
  local value_flags = { ["-u"] = true, ["-g"] = true, ["-C"] = true, ["-p"] = true, ["--user"] = true, ["--group"] = true }
  local index = 1
  while index <= #words do
    local value = words[index].value
    if value:match("^[A-Za-z_][A-Za-z0-9_]*=") then
      index = index + 1
    elseif wrappers[basename(value)] then
      index = index + 1
      while index <= #words and words[index].value:sub(1, 1) == "-" do
        if value_flags[words[index].value] then
          index = index + 2
        else
          index = index + 1
        end
      end
    else
      break
    end
  end
  return index
end

local function inspect(words)
  local git_at = first_command(words)
  if basename(words[git_at] and words[git_at].value or "") ~= "git" then
    return nil
  end

  local configs = {}
  local index = git_at + 1
  while index <= #words do
    local value = words[index].value
    if value == "-C" then
      index = index + 2
    elseif value == "-c" then
      if words[index + 1] then
        configs[#configs + 1] = words[index + 1].value
      end
      index = index + 2
    elseif value:sub(1, 1) == "-" then
      index = index + 1
    else
      break
    end
  end

  local subcommand = words[index] and words[index].value or ""
  local rest = {}
  for at = index + 1, #words do
    rest[#rest + 1] = words[at]
  end
  if subcommand == "commit" then
    local prefix = {}
    for at = 1, git_at - 1 do
      prefix[#prefix + 1] = words[at]
    end
    return commit_gate(rest, configs, prefix)
  end
  return nil
end

local function inspect_merge_request(words)
  local start = first_command(words)
  local command = words[start] and basename(words[start].value) or ""
  local subcommand = words[start + 1] and words[start + 1].value or ""
  if command == "gh" and subcommand == "pr" then
    local action = words[start + 2] and words[start + 2].value or ""
    if action == "create" or action == "new" then
      local rest = {}
      for index = start + 3, #words do
        rest[#rest + 1] = words[index]
      end
      return merge_request_gate(command, action, rest)
    end
  elseif command == "glab" and subcommand == "mr" then
    local action = words[start + 2] and words[start + 2].value or ""
    if action == "create" or action == "new" then
      local rest = {}
      for index = start + 3, #words do
        rest[#rest + 1] = words[index]
      end
      return merge_request_gate(command, action, rest)
    end
  end
  return nil
end

maki.api.set_slot("tool.bash.input", function(prev, input, ctx)
  local command = input and input.command
  if type(command) ~= "string" or not command:match("%f[%w]git%f[%W]") and not command:match("%f[%w]gh%f[%W]") and not command:match("%f[%w]glab%f[%W]") then
    return prev(input, ctx)
  end
  for _, words in ipairs(lex(command)) do
    local _, reason = inspect(words)
    if reason then
      return nil, reason
    end
    _, reason = inspect_merge_request(words)
    if reason then
      return nil, reason
    end
  end
  return prev(input, ctx)
end)
