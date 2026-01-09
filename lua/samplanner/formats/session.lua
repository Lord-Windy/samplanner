-- Session text format conversion (Markdown format)
local models = require('samplanner.domain.models')
local parsing = require('samplanner.utils.parsing')

local M = {}

-- Local aliases
local split_lines = parsing.split_lines
local finalize_section = parsing.finalize_section
local is_h2_header = parsing.is_h2_header
local is_h3_header = parsing.is_h3_header

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

-- Convert TimeLog to editable Markdown format
-- @param time_log: TimeLog - The time log to convert
-- @return string - Markdown format
function M.session_to_text(time_log)
  local lines = {}

  -- Session header
  table.insert(lines, "## Session")
  table.insert(lines, "Start: " .. format_timestamp(time_log.start_timestamp))
  table.insert(lines, "End:   " .. format_timestamp(time_log.end_timestamp))
  table.insert(lines, "Type:  " .. (time_log.session_type or ""))
  table.insert(lines, "Planned Duration (min): " .. (time_log.planned_duration_minutes or 0))
  table.insert(lines, "")

  -- Productivity metrics
  table.insert(lines, "## Productivity Metrics")
  table.insert(lines, "Focus Rating (1-5): " .. (time_log.focus_rating or 0))
  local energy_start = time_log.energy_level and time_log.energy_level.start or 0
  local energy_end = time_log.energy_level and time_log.energy_level["end"] or 0
  table.insert(lines, "Energy Level Start (1-5): " .. energy_start)
  table.insert(lines, "Energy Level End (1-5): " .. energy_end)
  table.insert(lines, "Context Switches: " .. (time_log.context_switches or 0))
  table.insert(lines, "")

  -- Notes section
  table.insert(lines, "## Notes")
  if time_log.notes and time_log.notes ~= "" then
    table.insert(lines, time_log.notes)
  end
  table.insert(lines, "")

  -- Interruptions section
  local interruption_header = string.format(
    "## Interruptions (minutes: %d)",
    time_log.interruption_minutes or 0
  )
  table.insert(lines, interruption_header)
  if time_log.interruptions and time_log.interruptions ~= "" then
    table.insert(lines, time_log.interruptions)
  end
  table.insert(lines, "")

  -- Deliverables section
  table.insert(lines, "## Deliverables")
  if time_log.deliverables and time_log.deliverables ~= "" then
    for line in time_log.deliverables:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
  end
  table.insert(lines, "")

  -- Defects section with H3 subsections
  table.insert(lines, "## Defects")
  table.insert(lines, "### Found")
  if time_log.defects and time_log.defects.found and time_log.defects.found ~= "" then
    for line in time_log.defects.found:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
  end
  table.insert(lines, "### Fixed")
  if time_log.defects and time_log.defects.fixed and time_log.defects.fixed ~= "" then
    for line in time_log.defects.fixed:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
  end
  table.insert(lines, "")

  -- Blockers section
  table.insert(lines, "## Blockers")
  if time_log.blockers and time_log.blockers ~= "" then
    for line in time_log.blockers:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
  end
  table.insert(lines, "")

  -- Retrospective section with H3 subsections
  table.insert(lines, "## Retrospective")
  table.insert(lines, "### What Went Well")
  if time_log.retrospective and time_log.retrospective.what_went_well and time_log.retrospective.what_went_well ~= "" then
    for line in time_log.retrospective.what_went_well:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
  end
  table.insert(lines, "### What Needs Improvement")
  if time_log.retrospective and time_log.retrospective.what_needs_improvement and time_log.retrospective.what_needs_improvement ~= "" then
    for line in time_log.retrospective.what_needs_improvement:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
  end
  table.insert(lines, "### Lessons Learned")
  if time_log.retrospective and time_log.retrospective.lessons_learned and time_log.retrospective.lessons_learned ~= "" then
    for line in time_log.retrospective.lessons_learned:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
  end
  table.insert(lines, "")

  -- Tasks section
  table.insert(lines, "## Tasks")
  if time_log.tasks and #time_log.tasks > 0 then
    for _, task_id in ipairs(time_log.tasks) do
      table.insert(lines, "- " .. task_id)
    end
  end

  return table.concat(lines, "\n")
end

-- Parse Markdown text back to TimeLog
-- @param text: string - Markdown format
-- @return TimeLog - Parsed time log
function M.text_to_session(text)
  local start_timestamp = ""
  local end_timestamp = ""
  local session_type = ""
  local planned_duration_minutes = 0
  local focus_rating = 0
  local energy_level = { start = 0, ["end"] = 0 }
  local context_switches = 0
  local notes = ""
  local interruptions = ""
  local interruption_minutes = 0
  local deliverables = ""
  local defects = { found = "", fixed = "" }
  local blockers = ""
  local retrospective = { what_went_well = "", what_needs_improvement = "", lessons_learned = "" }
  local tasks = {}

  local current_section = nil
  local current_subsection = nil
  local section_lines = {}

  local function save_subsection()
    if current_section == "defects" and current_subsection and #section_lines > 0 then
      local content = finalize_section(section_lines)
      if current_subsection == "found" then
        defects.found = content
      elseif current_subsection == "fixed" then
        defects.fixed = content
      end
    elseif current_section == "retrospective" and current_subsection and #section_lines > 0 then
      local content = finalize_section(section_lines)
      if current_subsection == "what_went_well" then
        retrospective.what_went_well = content
      elseif current_subsection == "what_needs_improvement" then
        retrospective.what_needs_improvement = content
      elseif current_subsection == "lessons_learned" then
        retrospective.lessons_learned = content
      end
    end
  end

  local function save_section()
    if current_section == "notes" and #section_lines > 0 then
      notes = finalize_section(section_lines)
    elseif current_section == "interruptions" and #section_lines > 0 then
      interruptions = finalize_section(section_lines)
    elseif current_section == "deliverables" and #section_lines > 0 then
      deliverables = finalize_section(section_lines)
    elseif current_section == "blockers" and #section_lines > 0 then
      blockers = finalize_section(section_lines)
    elseif current_section == "defects" or current_section == "retrospective" then
      save_subsection()
    end
  end

  -- Use (line)(\n) pattern to properly iterate lines including empty ones
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    local is_h2, h2_title = is_h2_header(line)
    local is_h3, h3_title = is_h3_header(line)

    if is_h2 then
      save_section()
      section_lines = {}
      current_subsection = nil

      if h2_title == "Session" then
        current_section = "session"
      elseif h2_title == "Productivity Metrics" then
        current_section = "metrics"
      elseif h2_title == "Notes" then
        current_section = "notes"
      elseif h2_title:match("^Interruptions") then
        -- Extract minutes from header
        local mins = h2_title:match("%(minutes:%s*(%d+)%)")
        if mins then
          interruption_minutes = tonumber(mins) or 0
        end
        current_section = "interruptions"
      elseif h2_title == "Deliverables" then
        current_section = "deliverables"
      elseif h2_title == "Defects" then
        current_section = "defects"
      elseif h2_title == "Blockers" then
        current_section = "blockers"
      elseif h2_title == "Retrospective" then
        current_section = "retrospective"
      elseif h2_title == "Tasks" then
        current_section = "tasks"
      else
        current_section = nil
      end

    elseif is_h3 and (current_section == "defects" or current_section == "retrospective") then
      save_subsection()
      section_lines = {}

      if h3_title == "Found" then
        current_subsection = "found"
      elseif h3_title == "Fixed" then
        current_subsection = "fixed"
      elseif h3_title == "What Went Well" then
        current_subsection = "what_went_well"
      elseif h3_title == "What Needs Improvement" then
        current_subsection = "what_needs_improvement"
      elseif h3_title == "Lessons Learned" then
        current_subsection = "lessons_learned"
      end

    elseif current_section == "session" then
      -- Parse session fields
      local start_val = line:match("^Start:%s*(.+)$")
      if start_val then
        start_timestamp = parse_timestamp(vim.trim(start_val))
      end
      local end_val = line:match("^End:%s*(.+)$")
      if end_val then
        end_timestamp = parse_timestamp(vim.trim(end_val))
      end
      local type_val = line:match("^Type:%s*(.+)$")
      if type_val then
        session_type = vim.trim(type_val)
      end
      local planned_val = line:match("^Planned Duration %(min%):%s*(%d+)")
      if planned_val then
        planned_duration_minutes = tonumber(planned_val) or 0
      end

    elseif current_section == "metrics" then
      -- Parse productivity metrics
      local focus_val = line:match("^Focus Rating %(1%-5%):%s*(%d+)")
      if focus_val then
        focus_rating = tonumber(focus_val) or 0
      end
      local energy_start_val = line:match("^Energy Level Start %(1%-5%):%s*(%d+)")
      if energy_start_val then
        energy_level.start = tonumber(energy_start_val) or 0
      end
      local energy_end_val = line:match("^Energy Level End %(1%-5%):%s*(%d+)")
      if energy_end_val then
        energy_level["end"] = tonumber(energy_end_val) or 0
      end
      local context_val = line:match("^Context Switches:%s*(%d+)")
      if context_val then
        context_switches = tonumber(context_val) or 0
      end

    elseif current_section == "tasks" then
      -- Parse task IDs (lines starting with "- ")
      local task_id = line:match("^%-%s*(.+)$")
      if task_id then
        table.insert(tasks, vim.trim(task_id))
      end

    elseif current_section == "notes" or current_section == "interruptions" or
           current_section == "deliverables" or current_section == "blockers" then
      -- Capture content
      if line ~= "" then
        table.insert(section_lines, line)
      elseif #section_lines > 0 then
        table.insert(section_lines, "")
      end

    elseif (current_section == "defects" or current_section == "retrospective") and current_subsection then
      -- Capture subsection content
      if line ~= "" then
        table.insert(section_lines, line)
      elseif #section_lines > 0 then
        table.insert(section_lines, "")
      end
    end
  end

  -- Save final section/subsection
  save_section()

  return models.TimeLog.new(
    start_timestamp,
    end_timestamp,
    notes,
    interruptions,
    interruption_minutes,
    tasks,
    session_type,
    planned_duration_minutes,
    focus_rating,
    energy_level,
    context_switches,
    defects,
    deliverables,
    blockers,
    retrospective
  )
end

return M
