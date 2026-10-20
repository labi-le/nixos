local VALUE_FLAGS = {
  ["-o"] = true,
  ["--push-option"] = true,
  ["--receive-pack"] = true,
  ["--exec"] = true,
  ["--repo"] = true,
}
local DETACH_FLAGS = {
  ["--"] = true,
  ["--detach"] = true,
  ["-d"] = true,
  ["-p"] = true,
  ["--patch"] = true,
  ["--orphan"] = true,
  ["--merge"] = true,
  ["-m"] = true,
}

local function trim(text)
  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function basename(token)
  return token:match("([^/]+)$") or token
end

local function lex(command)
  local commands, words = {}, {}
  local word, in_word = nil, false
  local index, length = 1, #command

  local function flush()
    if in_word then
      words[#words + 1] = { value = word or "" }
    end
    word, in_word = nil, false
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
      in_word = true
      word = (word or "") .. char
      index = index + 1
    end
  end

  finish()
  return commands
end

local function protected_branch(name)
  return name == "master"
    or name == "main"
    or name == "develop"
    or name == "trunk"
    or name:match("^RELEASE%-") ~= nil
    or name:match("^release/") ~= nil
    or name:match("^releases/") ~= nil
end

local function join(directory, name)
  if name:sub(1, 1) == "/" then
    return name
  end
  if directory:sub(-1) == "/" then
    return directory .. name
  end
  return directory .. "/" .. name
end

local function git_output(directory, arguments)
  local command = { "git", "-C", directory }
  for _, argument in ipairs(arguments) do
    command[#command + 1] = argument
  end
  local id = maki.fn.jobstart(command, { stderr = false, tail = 1 })
  if not id then
    return nil
  end
  local result = maki.fn.jobwait(id, 2000)
  if not result or result.exit_code ~= 0 then
    return nil
  end
  local text = trim(result.stdout or "")
  if text == "" then
    return nil
  end
  return text
end

local function symbolic_branch(directory)
  return git_output(directory, { "symbolic-ref", "--short", "-q", "HEAD" })
end

local function tracking_destination(directory, local_branch)
  local pushed = git_output(directory, {
    "rev-parse",
    "--abbrev-ref",
    "--symbolic-full-name",
    local_branch .. "@{push}",
  })
  if pushed then
    return pushed, "this branch's push target (branch.<name>.pushRemote / push.default)"
  end
  local upstream = git_output(directory, {
    "rev-parse",
    "--abbrev-ref",
    "--symbolic-full-name",
    local_branch .. "@{upstream}",
  })
  if upstream then
    return upstream, "this branch's upstream"
  end
  return nil, nil
end

local function branch_name(reference)
  local slash = reference:find("/", 1, true)
  if slash then
    return reference:sub(slash + 1)
  end
  return nil
end

local function refspec_destination(refspec)
  if not refspec then
    return nil
  end
  local destination = refspec:match(":(.*)$") or refspec
  if destination == "" then
    return nil
  end
  destination = destination:gsub("^%+", "")
  destination = destination:gsub("^refs/heads/", "")
  if destination == "" then
    return nil
  end
  return destination
end

local function refusal(local_branch, remote_branch, source, remote_protected)
  local danger
  if remote_protected then
    danger = "That is a protected branch — the push would land "
      .. local_branch
      .. " straight in "
      .. remote_branch
      .. "."
  else
    danger = "Local branch and remote branch disagree, so the push would update the wrong branch."
  end
  return nil,
    "Blocked: local branch `"
      .. local_branch
      .. "` would push to `"
      .. remote_branch
      .. "` ("
      .. source
      .. ").\n"
      .. danger
      .. "\n\nPoint the branch at its own remote branch, then push:\n  git branch --unset-upstream\n  git push -u origin <branch>"
end

local function push_gate(tokens, directory)
  local positional = {}
  local index = 1
  while index <= #tokens do
    local value = tokens[index].value
    if value == "--dry-run" or value == "-n" or value == "--help" then
      return nil
    elseif VALUE_FLAGS[value] then
      index = index + 2
    elseif value == "--force-with-lease" then
      index = index + 2
    elseif value:sub(1, 1) == "-" then
      index = index + 1
    else
      positional[#positional + 1] = value
      index = index + 1
    end
  end
  local refspec = positional[2]
  local explicit = refspec_destination(refspec)
  return {
    directory = directory,
    explicit = explicit,
    source = "the refspec you passed",
  }
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

local function inspect(words, state, cwd)
  local start = first_command(words)
  local command = basename(words[start] and words[start].value or "")
  if command == "cd" then
    for index = start + 1, #words do
      local value = words[index].value
      if value:sub(1, 1) ~= "-" then
        state.directory = join(state.directory, value)
        break
      end
    end
    return nil
  end

  local git_at = start
  if basename(words[git_at] and words[git_at].value or "") ~= "git" then
    return nil
  end

  local directory = state.directory
  local index = git_at + 1
  while index <= #words do
    local value = words[index].value
    if value == "-C" then
      local target = words[index + 1]
      if target then
        directory = join(directory, target.value)
      end
      index = index + 2
    elseif value == "-c" then
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

  if subcommand == "checkout" or subcommand == "switch" then
    local detach = false
    local candidate
    for _, token in ipairs(rest) do
      local value = token.value
      if value:sub(1, 1) == "-" then
        if DETACH_FLAGS[value] then
          detach = true
        end
      elseif not candidate then
        candidate = value
      end
    end
    if detach then
      state.predicted = nil
    else
      state.predicted = candidate
    end
    return nil
  end

  if subcommand ~= "push" then
    return nil
  end

  local push = push_gate(rest, directory)
  if not push then
    return nil
  end
  local local_branch = state.predicted or symbolic_branch(push.directory)
  if not local_branch then
    return nil
  end
  local remote_branch, source
  if push.explicit then
    remote_branch = branch_name(push.explicit) or push.explicit
    source = push.source
  else
    local reference, label = tracking_destination(push.directory, local_branch)
    remote_branch = reference and branch_name(reference)
    source = label
  end
  if not remote_branch or remote_branch == "" then
    return nil
  end
  if local_branch == remote_branch then
    return nil
  end
  if protected_branch(local_branch) then
    return nil
  end
  return refusal(local_branch, remote_branch, source or "the resolved push destination", protected_branch(remote_branch))
end

maki.api.set_slot("tool.bash.input", function(prev, input, ctx)
  local command = input and input.command
  if type(command) ~= "string" or not (command:match("%f[%w]git%f[%W]") or command:match("%f[%w]cd%f[%W]")) then
    return prev(input, ctx)
  end
  local cwd = (input.workdir and input.workdir ~= "" and input.workdir) or maki.uv.cwd() or "."
  local state = { directory = cwd, predicted = nil }
  for _, words in ipairs(lex(command)) do
    local _, reason = inspect(words, state, cwd)
    if reason then
      return nil, reason
    end
  end
  return prev(input, ctx)
end)
