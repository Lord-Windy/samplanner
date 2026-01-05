-- Migration helpers for converting between arrays and newline-separated strings
local M = {}

-- Convert array to newline-separated string with bullet points
-- @param array: table - Array of strings
-- @return string - Newline-separated string with "- " prefix for each item
function M.array_to_text(array)
  if not array or type(array) ~= "table" or #array == 0 then
    return ""
  end

  local lines = {}
  for _, item in ipairs(array) do
    if item and item ~= "" then
      table.insert(lines, "- " .. item)
    end
  end

  return table.concat(lines, "\n")
end

-- Convert newline-separated string (with or without bullets) to array
-- @param text: string - Newline-separated text, optionally with "- " prefix
-- @return table - Array of strings
function M.text_to_array(text)
  if not text or text == "" then
    return {}
  end

  local items = {}
  for line in text:gmatch("[^\r\n]+") do
    -- Remove leading "- " if present, then trim
    local item = line:match("^%-%s*(.*)$") or line
    item = vim.trim(item)
    if item ~= "" then
      table.insert(items, item)
    end
  end

  return items
end

-- Migrate a table's array fields to string fields (forward migration)
-- @param tbl: table - Table with array fields
-- @param field_names: table - Array of field names to migrate
-- @return table - Table with string fields
function M.migrate_arrays_to_strings(tbl, field_names)
  if not tbl or type(tbl) ~= "table" then
    return tbl
  end

  local result = vim.deepcopy(tbl)

  for _, field_name in ipairs(field_names) do
    if result[field_name] and type(result[field_name]) == "table" then
      result[field_name] = M.array_to_text(result[field_name])
    end
  end

  return result
end

-- Migrate a table's string fields to array fields (reverse migration)
-- @param tbl: table - Table with string fields
-- @param field_names: table - Array of field names to migrate
-- @return table - Table with array fields
function M.migrate_strings_to_arrays(tbl, field_names)
  if not tbl or type(tbl) ~= "table" then
    return tbl
  end

  local result = vim.deepcopy(tbl)

  for _, field_name in ipairs(field_names) do
    if result[field_name] and type(result[field_name]) == "string" then
      result[field_name] = M.text_to_array(result[field_name])
    end
  end

  return result
end

return M
