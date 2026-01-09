-- Shared table utilities for Samplanner
local M = {}

-- Sort keys numerically by dot-separated segments (e.g., "1.2.3" < "1.2.10")
-- @param t: table - The table whose keys to sort
-- @return table - Array of sorted keys
function M.sorted_keys(t)
  local keys = {}
  for k in pairs(t) do
    table.insert(keys, k)
  end
  table.sort(keys, function(a, b)
    local a_parts = {}
    for part in a:gmatch("(%d+)") do
      table.insert(a_parts, tonumber(part))
    end
    local b_parts = {}
    for part in b:gmatch("(%d+)") do
      table.insert(b_parts, tonumber(part))
    end
    for i = 1, math.max(#a_parts, #b_parts) do
      local a_val = a_parts[i] or 0
      local b_val = b_parts[i] or 0
      if a_val ~= b_val then
        return a_val < b_val
      end
    end
    return false
  end)
  return keys
end

-- Apply updates from source table to target for specified fields
-- @param target: table - The object to update
-- @param updates: table - The updates to apply
-- @param fields: table - Array of field names to check
function M.apply_updates(target, updates, fields)
  for _, field in ipairs(fields) do
    if updates[field] ~= nil then
      target[field] = updates[field]
    end
  end
end

return M
