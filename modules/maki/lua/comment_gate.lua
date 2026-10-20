local SUFFIX = "\n\nAdjust the edit and run it again. Comment policy: the code-comments skill."

local SLASH_EXTENSIONS = {
  "ts", "tsx", "js", "jsx", "mjs", "cjs", "vue", "svelte", "astro", "scss", "less",
  "go", "rs", "zig", "c", "h", "cc", "cpp", "hpp", "cs", "java", "kt", "kts", "scala",
  "groovy", "gradle", "swift", "dart", "sol", "proto", "php",
}
local HASH_EXTENSIONS = {
  "nix", "py", "sh", "bash", "zsh", "ps1", "rb", "pl", "ex", "exs", "jl", "r", "tf",
  "tfvars", "hcl", "yaml", "yml", "toml",
}
local DASH_EXTENSIONS = { "sql", "lua", "hs" }

local SLASH, HASH, DASH = {}, {}, {}
for _, extension in ipairs(SLASH_EXTENSIONS) do
  SLASH[extension] = true
end
for _, extension in ipairs(HASH_EXTENSIONS) do
  HASH[extension] = true
end
for _, extension in ipairs(DASH_EXTENSIONS) do
  DASH[extension] = true
end

local SCAFFOLDING = { "TODO", "FIXME", "XXX", "HACK", "WIP", "TBD" }
local PARKED_KEYWORDS = {
  "if", "for", "while", "switch", "return", "import", "export", "from", "def", "class",
  "fn", "func", "function", "let", "const", "var", "await", "async", "use", "pub",
}
local SAFE_HOMES = { ["/home/user"] = true, ["/home/foo"] = true, ["/home/bar"] = true, ["/home/example"] = true }
local SAFE_HOSTS = { ["internal"] = true, ["intranet"] = true, ["corp"] = true, ["lan"] = true, ["prod"] = true, ["prd"] = true, ["stage"] = true, ["stg"] = true }

local function deny(reason)
  return nil, "Blocked: " .. reason .. SUFFIX
end

local function trim(text)
  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function syntax_of(path)
  local extension = path:match("%.([%w]+)$")
  if not extension then
    return nil
  end
  extension = extension:lower()
  if SLASH[extension] then
    return "slash"
  end
  if HASH[extension] then
    return "hash"
  end
  if DASH[extension] then
    return "dash"
  end
  return nil
end

local function split_lines(text)
  local lines = {}
  for line in (text .. "\n"):gmatch("(.-)\n") do
    lines[#lines + 1] = line
  end
  if #lines > 0 and lines[#lines] == "" then
    lines[#lines] = nil
  end
  return lines
end

local function scan_slash(line, state, out)
  local index, quote = 1, nil
  while index <= #line do
    local char = line:sub(index, index)
    if state.block then
      local close = line:find("*/", index, true)
      if close then
        out[#out + 1] = line:sub(index, close - 1)
        state.block = false
        index = close + 2
      else
        out[#out + 1] = line:sub(index)
        return
      end
    elseif quote then
      if char == "\\" then
        index = index + 2
      elseif char == quote then
        quote = nil
        index = index + 1
      else
        index = index + 1
      end
    elseif char == "'" or char == '"' or char == "`" then
      quote = char
      index = index + 1
    elseif line:sub(index, index + 1) == "/*" then
      state.block = true
      index = index + 2
    elseif line:sub(index, index + 1) == "//" then
      out[#out + 1] = line:sub(index + 2)
      return
    else
      index = index + 1
    end
  end
end

local function scan_line_marker(line, marker, shebang, out)
  local index, quote = 1, nil
  while index <= #line do
    local char = line:sub(index, index)
    if quote then
      if char == "\\" then
        index = index + 2
      elseif char == quote then
        quote = nil
        index = index + 1
      else
        index = index + 1
      end
    elseif char == "'" or char == '"' or char == "`" then
      quote = char
      index = index + 1
    elseif line:sub(index, index + #marker - 1) == marker then
      if shebang and index == 1 then
        return
      end
      out[#out + 1] = line:sub(index + #marker)
      return
    else
      index = index + 1
    end
  end
end

local function credential(line)
  local candidate = line:match("gh[pousr]_[A-Za-z0-9]+")
  if candidate and #candidate:sub(5) >= 20 then
    return candidate
  end
  candidate = line:match("github_pat_[A-Za-z0-9_]+")
  if candidate and #candidate:sub(12) >= 20 then
    return candidate
  end
  candidate = line:match("sk%-[A-Za-z0-9]+")
  if candidate and #candidate:sub(4) >= 20 then
    return candidate
  end
  candidate = line:match("AKIA[0-9A-Z]+")
  if candidate and #candidate:sub(5) >= 16 then
    return candidate
  end
  candidate = line:match("xox[baprs]%-[A-Za-z0-9%-]+")
  if candidate and #candidate >= 12 then
    return candidate
  end
  candidate = line:match("eyJ[A-Za-z0-9_%-]+%.")
  if candidate and #candidate >= 12 then
    return candidate
  end
  if line:find("BEGIN [A-Z ]*PRIVATE KEY", 1) then
    return "private key"
  end
  return nil
end

local function scaffolding(comment)
  for _, marker in ipairs(SCAFFOLDING) do
    if comment:find("%f[%w]" .. marker .. "%f[%W]") then
      return marker
    end
  end
  return nil
end

local function parked_code(comment)
  local text = trim(comment)
  if text == "" then
    return false
  end
  if text:match("^[%)%]%}'\"`]+;?$") or text:match("^''%s*;?$") then
    return true
  end
  if text:match("^[\"'%[]?[A-Za-z_$][%w$.[%]\"'%-]*%s*=%s*.+;$") then
    return true
  end
  if text:match("^[\"'%[]?[A-Za-z_$][%w$.[%]\"'%-]*%s*=%s*[%w$.]+%(.*%)$") then
    return true
  end
  local lower = text:lower()
  for _, keyword in ipairs(PARKED_KEYWORDS) do
    if lower:sub(1, #keyword) == keyword then
      local after = lower:sub(#keyword + 1, #keyword + 1)
      if after == "" or after:match("[%s%(]") then
        if text:sub(-1) == ";" or text:sub(-1) == "{" then
          return true
        end
      end
    end
  end
  if text:match("^[%w$.]+%(.*%);?$") then
    return true
  end
  return false
end

local function safe_email(domain)
  local lower = domain:lower()
  if lower == "example.com" or lower == "example.org" or lower == "example.net" then
    return true
  end
  if lower == "invalid" or lower == "test" or lower == "localhost" then
    return true
  end
  return false
end

local function safe_ip(address)
  local a, b, c, d = address:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
  if not a then
    return true
  end
  a, b, c, d = tonumber(a), tonumber(b), tonumber(c), tonumber(d)
  if a == 192 and b == 0 and c == 2 then
    return true
  end
  if a == 198 and b == 51 and c == 100 then
    return true
  end
  if a == 203 and b == 0 and c == 113 then
    return true
  end
  if address == "127.0.0.1" or address == "0.0.0.0" or address == "255.255.255.255" then
    return true
  end
  return false
end

local function real_data(comment)
  local email = comment:match("[%w._%%+%-]+@[%w%-%.]+")
  if email then
    local domain = email:match("@(.+)$")
    if domain and not safe_email(domain) then
      return email
    end
  end
  for address in comment:gmatch("(%d+%.%d+%.%d+%.%d+)") do
    if not safe_ip(address) then
      return address
    end
  end
  for suffix in pairs(SAFE_HOSTS) do
    local host = comment:match("[%w%-%.]+%." .. suffix .. "%f[%W]")
    if host then
      return host
    end
  end
  for path in comment:gmatch("(/home/[%w%._%-]+)") do
    if not SAFE_HOMES[path] then
      return path
    end
  end
  return nil
end

local function check_comments(lines, syntax)
  local state = { block = false }
  for number, line in ipairs(lines) do
    local found = {}
    if syntax == "slash" then
      scan_slash(line, state, found)
    elseif syntax == "hash" then
      scan_line_marker(line, "#", number == 1 and line:sub(1, 2) == "#!", found)
    else
      scan_line_marker(line, "--", false, found)
    end
    local token = credential(line)
    if token then
      return deny("the added line carries a credential (`" .. token .. "`); never write a real token into the tree")
    end
    for _, comment in ipairs(found) do
      if trim(comment) ~= "" then
        local marker = scaffolding(comment)
        if marker then
          return deny(
            "the added comment carries a scaffolding marker (`"
              .. marker
              .. "`); finish the work or delete the line"
          )
        end
        if parked_code(comment) then
          return deny(
            "the added comment is commented-out code (`"
              .. trim(comment):sub(1, 40)
              .. "`); delete it, git remembers"
          )
        end
        local data = real_data(comment)
        if data then
          return deny(
            "the added comment carries real data (`"
              .. data
              .. "`); use a neutral placeholder such as `foo`, `bar`, `user@example.com` or `192.0.2.1`"
          )
        end
      end
    end
  end
  return nil
end

local function inspect(tool, input)
  local path = input and input.path
  if type(path) ~= "string" then
    return nil
  end
  local syntax = syntax_of(path)
  if not syntax then
    return nil
  end
  local lines = {}
  if tool == "write" then
    if type(input.content) == "string" then
      lines = split_lines(input.content)
    end
  elseif tool == "edit" then
    if type(input.new_string) == "string" then
      lines = split_lines(input.new_string)
    end
  elseif tool == "multiedit" and type(input.edits) == "table" then
    for _, edit in ipairs(input.edits) do
      if type(edit.new_string) == "string" then
        for _, line in ipairs(split_lines(edit.new_string)) do
          lines[#lines + 1] = line
        end
      end
    end
  end
  if #lines == 0 then
    return nil
  end
  return check_comments(lines, syntax)
end

for _, tool in ipairs({ "write", "edit", "multiedit" }) do
  maki.api.set_slot("tool." .. tool .. ".input", function(prev, input, ctx)
    local _, reason = inspect(tool, input)
    if reason then
      return nil, reason
    end
    return prev(input, ctx)
  end)
end
