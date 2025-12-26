-- Session text format conversion
local models = require('samplanner.domain.models')

local M = {}

-- Format ISO timestamp to human-readable format
-- @param timestamp: string - ISO format timestamp (e.g., "2024-01-15T09:00:00Z")
-- @return string - Human readable format (e.g., "2024-01-15 09:00")
local function format_timestamp(timestamp)
  if not timestamp or timestamp == "" then
    return ""
  end
  -- Convert "2024-01-15T09:00:00Z" to "2024-01-15 09:00"
  local date, time = timestamp:match("^(%d%d%d%d%-%d%d%-%d%d)T(%d%d:%d%d)")
  if date and time then
    return date .. " " .. time
  end
  return timestamp
end

-- Parse human-readable timestamp back to ISO format
-- @param text: string - Human readable format (e.g., "2024-01-15 09:00")
-- @return string - ISO format timestamp (e.g., "2024-01-15T09:00:00Z")
local function parse_timestamp(text)
  if not text or text == "" then
    return ""
  end
  -- Convert "2024-01-15 09:00" to "2024-01-15T09:00:00Z"
  local date, time = text:match("^(%d%d%d%d%-%d%d%-%d%d)%s+(%d%d:%d%d)")
  if date and time then
    return date .. "T" .. time .. ":00Z"
  end
  return text
end

-- Convert TimeLog to editable text format
-- @param time_log: TimeLog - The time log to convert
-- @return string - Human-readable text format
function M.session_to_text(time_log)
  local lines = {}

  -- Session header
  table.insert(lines, "── Session ──────────────────────────")
  table.insert(lines, "Start: " .. format_timestamp(time_log.start_timestamp))
  table.insert(lines, "End:   " .. format_timestamp(time_log.end_timestamp))
  table.insert(lines, "")

  -- Notes section
  table.insert(lines, "── Notes ────────────────────────────")
  if time_log.notes and time_log.notes ~= "" then
    table.insert(lines, time_log.notes)
  end
  table.insert(lines, "")

  -- Interruptions section
  local interruption_header = string.format(
    "── Interruptions (minutes: %d) ──────",
    time_log.interruption_minutes or 0
  )
  table.insert(lines, interruption_header)
  if time_log.interruptions and time_log.interruptions ~= "" then
    table.insert(lines, time_log.interruptions)
  end
  table.insert(lines, "")

  -- Tasks section
  table.insert(lines, "── Tasks ────────────────────────────")
  if time_log.tasks and #time_log.tasks > 0 then
    for _, task_id in ipairs(time_log.tasks) do
      table.insert(lines, "- " .. task_id)
    end
  end

  return table.concat(lines, "\n")
end

-- Parse text back to TimeLog
-- @param text: string - Human-readable text format
-- @return TimeLog - Parsed time log
function M.text_to_session(text)
  local start_timestamp = ""
  local end_timestamp = ""
  local notes = ""
  local interruptions = ""
  local interruption_minutes = 0
  local tasks = {}

  local current_section = nil
  local section_content = {}

  for line in text:gmatch("[^\r\n]*") do
    -- Check for section headers
    if line:match("^── Session") then
      current_section = "session"
      section_content = {}
    elseif line:match("^── Notes") then
      current_section = "notes"
      section_content = {}
    elseif line:match("^── Interruptions") then
      -- Extract minutes from header
      local mins = line:match("%(minutes:%s*(%d+)%)")
      if mins then
        interruption_minutes = tonumber(mins) or 0
      end
      current_section = "interruptions"
      section_content = {}
    elseif line:match("^── Tasks") then
      current_section = "tasks"
      section_content = {}
    elseif current_section == "session" then
      -- Parse start/end timestamps
      local start_val = line:match("^Start:%s*(.+)$")
      if start_val then
        start_timestamp = parse_timestamp(vim.trim(start_val))
      end
      local end_val = line:match("^End:%s*(.+)$")
      if end_val then
        end_timestamp = parse_timestamp(vim.trim(end_val))
      end
    elseif current_section == "notes" then
      if line ~= "" then
        table.insert(section_content, line)
      end
      notes = table.concat(section_content, "\n")
    elseif current_section == "interruptions" then
      if line ~= "" then
        table.insert(section_content, line)
      end
      interruptions = table.concat(section_content, "\n")
    elseif current_section == "tasks" then
      -- Parse task IDs (lines starting with "- ")
      local task_id = line:match("^%-%s*(.+)$")
      if task_id then
        table.insert(tasks, vim.trim(task_id))
      end
    end
  end

  return models.TimeLog.new(
    start_timestamp,
    end_timestamp,
    notes,
    interruptions,
    interruption_minutes,
    tasks
  )
end

return M
