local M = {}

function M.read(path, name)
  local text, err = maki.fs.read(path)
  if not text then
    return nil, err
  end
  for line in text:gmatch("[^\r\n]+") do
    local value = line:match("^" .. name .. "=(.*)$")
    if value and value ~= "" then
      return value
    end
  end
  return nil, "missing " .. name
end

return M
