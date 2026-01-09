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

-- ============================================================================
-- Markdown Format Utilities
-- ============================================================================

-- Create H1 header
-- @param title: string - Header text
-- @return string - "# Title\n"
function M.format_h1(title)
  return "# " .. title .. "\n"
end

-- Create H2 header
-- @param section: string - Section name
-- @return string - "## Section\n"
function M.format_h2(section)
  return "## " .. section .. "\n"
end

-- Create H3 header
-- @param subsection: string - Subsection name
-- @return string - "### Subsection\n"
function M.format_h3(subsection)
  return "### " .. subsection .. "\n"
end

-- Format task title with ID and name
-- @param id: string - Task ID
-- @param name: string - Task name
-- @return string - "# Task: ID - Name\n"
function M.format_task_title(id, name)
  return "# Task: " .. id .. " - " .. name .. "\n"
end

-- Format a Markdown section with H2 header and content
-- @param lines: table - Array to append formatted lines to
-- @param header: string - Section header text
-- @param content: string - Content to format (may be multiline)
function M.format_md_section(lines, header, content)
  table.insert(lines, "## " .. header)
  if content and content ~= "" then
    for _, line in ipairs(M.split_lines(content)) do
      table.insert(lines, line)
    end
  end
  table.insert(lines, "")
end

-- Format a Markdown subsection with H3 header and content
-- @param lines: table - Array to append formatted lines to
-- @param header: string - Subsection header text
-- @param content: string - Content to format (may be multiline)
function M.format_md_subsection(lines, header, content)
  table.insert(lines, "### " .. header)
  if content and content ~= "" then
    for _, line in ipairs(M.split_lines(content)) do
      table.insert(lines, line)
    end
  end
  table.insert(lines, "")
end

-- Format a GFM-style checkbox
-- @param checked: boolean - Whether checkbox is checked
-- @param label: string - Checkbox label
-- @return string - "- [x] Label" or "- [ ] Label"
function M.format_gfm_checkbox(checked, label)
  local mark = checked and "[x]" or "[ ]"
  return "- " .. mark .. " " .. label
end

-- Format a vertical group of GFM checkboxes
-- @param options: table - Array of {label, value} pairs
-- @param selected_value: string - The currently selected value
-- @return string - Multiline string of checkboxes
function M.format_gfm_checkbox_group(options, selected_value)
  local result = {}
  for _, opt in ipairs(options) do
    local checked = (opt.value == selected_value)
    table.insert(result, M.format_gfm_checkbox(checked, opt.label))
  end
  return table.concat(result, "\n")
end

-- Parse task ID and name from H1 header
-- @param line: string - Line to parse
-- @return string, string - Task ID and name, or nil, nil if not a task header
function M.parse_h1_task_header(line)
  local id, name = line:match("^# Task:%s*([^%-]+)%s*%-%s*(.*)$")
  if id then
    return vim.trim(id), vim.trim(name)
  end
  return nil, nil
end

-- Check if line is an H2 header and extract title
-- @param line: string - Line to check
-- @return boolean, string - true and title if H2, false and nil otherwise
function M.is_h2_header(line)
  local title = line:match("^## ([^#].*)$")
  if title then
    return true, vim.trim(title)
  end
  return false, nil
end

-- Check if line is an H3 header and extract title
-- @param line: string - Line to check
-- @return boolean, string - true and title if H3, false and nil otherwise
function M.is_h3_header(line)
  local title = line:match("^### ([^#].*)$")
  if title then
    return true, vim.trim(title)
  end
  return false, nil
end

-- Parse checked value from a GFM checkbox line
-- @param line: string - Line to parse
-- @param options: table - Array of {pattern, value} pairs
-- @return string - Matched value or nil if not checked
function M.parse_gfm_checkbox_value(line, options)
  -- Check if line is a checked GFM checkbox
  if not line:match("^%- %[[xX]%]") then
    return nil
  end

  for _, opt in ipairs(options) do
    if line:match("%[x%]%s+" .. opt.pattern) or line:match("%[X%]%s+" .. opt.pattern) then
      return opt.value
    end
  end
  return nil
end

return M
