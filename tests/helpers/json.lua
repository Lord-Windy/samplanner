-- Simple JSON encoder/decoder for testing
-- This is a minimal implementation for test purposes only

local M = {}

local function encode_value(val, indent_level)
  local indent = string.rep("  ", indent_level or 0)
  local next_indent = string.rep("  ", (indent_level or 0) + 1)
  
  local val_type = type(val)
  
  if val_type == "string" then
    return '"' .. val:gsub('"', '\\"') .. '"'
  elseif val_type == "number" or val_type == "boolean" then
    return tostring(val)
  elseif val_type == "table" then
    -- Check if it's an array
    local is_array = #val > 0
    if is_array then
      local parts = {}
      for i, v in ipairs(val) do
        table.insert(parts, next_indent .. encode_value(v, (indent_level or 0) + 1))
      end
      return "[\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "]"
    else
      local parts = {}
      for k, v in pairs(val) do
        local key = type(k) == "string" and ('"' .. k .. '"') or tostring(k)
        table.insert(parts, next_indent .. key .. ": " .. encode_value(v, (indent_level or 0) + 1))
      end
      return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
    end
  elseif val == nil then
    return "null"
  end
  
  return "null"
end

function M.encode(val)
  return encode_value(val, 0)
end

-- Simple JSON decoder (very basic, for test purposes)
function M.decode(str)
  -- Remove whitespace
  str = str:gsub("^%s+", ""):gsub("%s+$", "")
  
  -- Try to use loadstring with a safe environment if possible
  -- This is a simplified approach for testing
  local json_str = str
    :gsub("%[", "{")
    :gsub("%]", "}")
    :gsub("(%w+)%s*:", '"%1":')
    :gsub('"(%w+)":', '["%1"]=')
    :gsub("null", "nil")
  
  -- For actual use, you'd want a proper JSON parser
  -- This is just for basic testing
  local func, err = loadstring("return " .. json_str)
  if func then
    return func()
  end
  
  -- Fallback: just return empty table
  return {}
end

return M
