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
  table.insert(lines, "Type:  " .. (time_log.session_type or ""))
  table.insert(lines, "Planned Duration (min): " .. (time_log.planned_duration_minutes or 0))
  table.insert(lines, "")

  -- Productivity metrics
  table.insert(lines, "── Productivity Metrics ─────────────")
  table.insert(lines, "Focus Rating (1-5): " .. (time_log.focus_rating or 0))
  local energy_start = time_log.energy_level and time_log.energy_level.start or 0
  local energy_end = time_log.energy_level and time_log.energy_level["end"] or 0
  table.insert(lines, "Energy Level Start (1-5): " .. energy_start)
  table.insert(lines, "Energy Level End (1-5): " .. energy_end)
  table.insert(lines, "Context Switches: " .. (time_log.context_switches or 0))
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

  -- Deliverables section
  table.insert(lines, "── Deliverables ─────────────────────")
  if time_log.deliverables and time_log.deliverables ~= "" then
    -- Output text as-is (no forced bullets)
    for line in time_log.deliverables:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
  end
  table.insert(lines, "")

  -- Defects section
  table.insert(lines, "── Defects ──────────────────────────")
  table.insert(lines, "Found:")
  if time_log.defects and time_log.defects.found and time_log.defects.found ~= "" then
    for line in time_log.defects.found:gmatch("[^\r\n]+") do
      table.insert(lines, "  " .. line)
    end
  end
  table.insert(lines, "Fixed:")
  if time_log.defects and time_log.defects.fixed and time_log.defects.fixed ~= "" then
    for line in time_log.defects.fixed:gmatch("[^\r\n]+") do
      table.insert(lines, "  " .. line)
    end
  end
  table.insert(lines, "")

  -- Blockers section
  table.insert(lines, "── Blockers ─────────────────────────")
  if time_log.blockers and time_log.blockers ~= "" then
    for line in time_log.blockers:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
  end
  table.insert(lines, "")

  -- Retrospective section
  table.insert(lines, "── Retrospective ────────────────────")
  table.insert(lines, "What Went Well:")
  if time_log.retrospective and time_log.retrospective.what_went_well and time_log.retrospective.what_went_well ~= "" then
    for line in time_log.retrospective.what_went_well:gmatch("[^\r\n]+") do
      table.insert(lines, "  " .. line)
    end
  end
  table.insert(lines, "What Needs Improvement:")
  if time_log.retrospective and time_log.retrospective.what_needs_improvement and time_log.retrospective.what_needs_improvement ~= "" then
    for line in time_log.retrospective.what_needs_improvement:gmatch("[^\r\n]+") do
      table.insert(lines, "  " .. line)
    end
  end
  table.insert(lines, "Lessons Learned:")
  if time_log.retrospective and time_log.retrospective.lessons_learned and time_log.retrospective.lessons_learned ~= "" then
    for line in time_log.retrospective.lessons_learned:gmatch("[^\r\n]+") do
      table.insert(lines, "  " .. line)
    end
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
  local section_content = {}
  local section_lines = {}  -- For capturing free-form content

  for line in text:gmatch("[^\r\n]*") do
    -- Check for section headers
    if line:match("^── Session") then
      current_section = "session"
      section_content = {}
    elseif line:match("^── Productivity Metrics") then
      current_section = "metrics"
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
    elseif line:match("^── Deliverables") then
      current_section = "deliverables"
      section_content = {}
      section_lines = {}
    elseif line:match("^── Defects") then
      current_section = "defects"
      current_subsection = nil
      section_content = {}
      section_lines = {}
    elseif line:match("^── Blockers") then
      current_section = "blockers"
      section_content = {}
      section_lines = {}
    elseif line:match("^── Retrospective") then
      current_section = "retrospective"
      current_subsection = nil
      section_content = {}
      section_lines = {}
    elseif line:match("^── Tasks") then
      current_section = "tasks"
      section_content = {}
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
    elseif current_section == "deliverables" then
      -- Capture all non-header lines
      if not line:match("^──") and line ~= "" then
        if deliverables ~= "" then
          deliverables = deliverables .. "\n" .. line
        else
          deliverables = line
        end
      end
    elseif current_section == "defects" then
      if line:match("^Found:") then
        current_subsection = "found"
        section_lines = {}
      elseif line:match("^Fixed:") then
        -- Save previous subsection
        if current_subsection == "found" and #section_lines > 0 then
          defects.found = table.concat(section_lines, "\n")
        end
        current_subsection = "fixed"
        section_lines = {}
      else
        -- Capture ALL indented text (2+ spaces)
        if line:match("^%s%s+") then
          local content = line:match("^%s%s+(.*)$")
          if content and content ~= "" then
            table.insert(section_lines, content)
          end
        end
      end
    elseif current_section == "blockers" then
      -- Capture all non-header lines
      if not line:match("^──") and line ~= "" then
        if blockers ~= "" then
          blockers = blockers .. "\n" .. line
        else
          blockers = line
        end
      end
    elseif current_section == "retrospective" then
      if line:match("^What Went Well:") then
        current_subsection = "what_went_well"
        section_lines = {}
      elseif line:match("^What Needs Improvement:") then
        -- Save previous subsection
        if current_subsection == "what_went_well" and #section_lines > 0 then
          retrospective.what_went_well = table.concat(section_lines, "\n")
        end
        current_subsection = "what_needs_improvement"
        section_lines = {}
      elseif line:match("^Lessons Learned:") then
        -- Save previous subsection
        if current_subsection == "what_needs_improvement" and #section_lines > 0 then
          retrospective.what_needs_improvement = table.concat(section_lines, "\n")
        end
        current_subsection = "lessons_learned"
        section_lines = {}
      else
        -- Capture ALL indented text (2+ spaces)
        if line:match("^%s%s+") then
          local content = line:match("^%s%s+(.*)$")
          if content and content ~= "" then
            table.insert(section_lines, content)
          end
        end
      end
    elseif current_section == "tasks" then
      -- Parse task IDs (lines starting with "- ")
      local task_id = line:match("^%-%s*(.+)$")
      if task_id then
        table.insert(tasks, vim.trim(task_id))
      end
    end
  end

  -- Save final subsections
  if current_section == "defects" and current_subsection == "fixed" and #section_lines > 0 then
    defects.fixed = table.concat(section_lines, "\n")
  end

  if current_section == "retrospective" and current_subsection == "lessons_learned" and #section_lines > 0 then
    retrospective.lessons_learned = table.concat(section_lines, "\n")
  end

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
