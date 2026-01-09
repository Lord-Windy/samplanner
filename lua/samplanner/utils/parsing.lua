-- Shared parsing utilities for Samplanner text formats
local M = {}

-- Normalize consecutive empty lines (collapse multiple empty lines into at most one)
-- @param lines: table - Array of lines
-- @return table - Normalized array of lines
function M.normalize_empty_lines(lines)
  local result = {}
  local prev_empty = false

  for _, line in ipairs(lines) do
    local is_empty = (line == "")
    if not (is_empty and prev_empty) then
      table.insert(result, line)
    end
    prev_empty = is_empty
  end

  return result
end

-- Trim leading and trailing empty lines from an array
-- @param lines: table - Array of lines
-- @return table - Trimmed array of lines
function M.trim_empty_lines(lines)
  while #lines > 0 and lines[#lines] == "" do
    table.remove(lines)
  end
  while #lines > 0 and lines[1] == "" do
    table.remove(lines, 1)
  end
  return lines
end

-- Process section lines: normalize and trim, then join
-- @param section_lines: table - Array of lines to process
-- @return string - Processed content as string
function M.finalize_section(section_lines)
  if #section_lines == 0 then
    return ""
  end
  section_lines = M.normalize_empty_lines(section_lines)
  section_lines = M.trim_empty_lines(section_lines)
  return table.concat(section_lines, "\n")
end

-- Split string by newlines, preserving empty lines
-- @param str: string - The string to split
-- @return table - Array of lines
function M.split_lines(str)
  local lines = {}
  local pos = 1
  while true do
    local nl = str:find("\n", pos, true)
    if nl then
      table.insert(lines, str:sub(pos, nl - 1))
      pos = nl + 1
    else
      table.insert(lines, str:sub(pos))
      break
    end
  end
  return lines
end

-- Capture indented content line into section_lines array
-- @param line: string - The line to process
-- @param section_lines: table - Array to append content to
-- @param indent_size: number - Expected indentation size (default 2)
function M.capture_indented_line(line, section_lines, indent_size)
  indent_size = indent_size or 2
  local pattern = "^" .. string.rep(" ", indent_size)

  if line == "" then
    if #section_lines > 0 then
      table.insert(section_lines, "")
    end
  elseif line:match(pattern) then
    local content = line:sub(indent_size + 1)
    table.insert(section_lines, content)
  elseif line:match("^%s+") then
    local content = line:match("^%s+(.*)$")
    if content and content ~= "" then
      table.insert(section_lines, content)
    end
  else
    table.insert(section_lines, line)
  end
end

-- Capture free-form content (non-indented) into lines array
-- @param line: string - The line to process
-- @param lines: table - Array to append content to
function M.capture_freeform_line(line, lines)
  if line ~= "" then
    table.insert(lines, line)
  elseif #lines > 0 then
    table.insert(lines, "")
  end
end

-- Format a section with header and indented content
-- @param lines: table - Array to append formatted lines to
-- @param header: string - Section header text
-- @param content: string - Content to format (may be multiline)
-- @param indent: string - Indentation prefix (default "  ")
-- @param empty_placeholder: string - Placeholder when content is empty (default "- ")
function M.format_section(lines, header, content, indent, empty_placeholder)
  indent = indent or "  "
  empty_placeholder = empty_placeholder or "- "

  table.insert(lines, header)
  if content and content ~= "" then
    for _, line in ipairs(M.split_lines(content)) do
      table.insert(lines, indent .. line)
    end
  else
    table.insert(lines, indent .. empty_placeholder)
  end
  table.insert(lines, "")
end

-- Format a simple section with header and plain content (no indentation)
-- @param lines: table - Array to append formatted lines to
-- @param header: string - Section header text
-- @param content: string - Content to format
function M.format_plain_section(lines, header, content)
  table.insert(lines, header)
  if content and content ~= "" then
    table.insert(lines, content)
  else
    table.insert(lines, "")
  end
  table.insert(lines, "")
end

-- Helper to format a checkbox based on value
-- @param is_checked: boolean - Whether checkbox is checked
-- @return string - "[x]" or "[ ]"
function M.checkbox(is_checked)
  return is_checked and "[x]" or "[ ]"
end

-- Helper to get checkbox value from line
-- @param line: string - The line to check
-- @param options: table - Array of {pattern, value} pairs
-- @return string - Matched value or ""
function M.get_checked_value(line, options)
  for _, opt in ipairs(options) do
    if line:match("%[x%]%s+" .. opt.pattern) or line:match("%[X%]%s+" .. opt.pattern) then
      return opt.value
    end
  end
  return ""
end

return M
