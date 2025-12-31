-- Task text format conversion
local models = require('samplanner.domain.models')

local M = {}

-- Helper to format a checkbox based on value
local function checkbox(is_checked)
  return is_checked and "[x]" or "[ ]"
end

-- Helper to get checkbox value from line
local function get_checked_value(line, options)
  for _, opt in ipairs(options) do
    if line:match("%[x%]%s+" .. opt.pattern) or line:match("%[X%]%s+" .. opt.pattern) then
      return opt.value
    end
  end
  return ""
end

-- Convert Estimation to text format
local function estimation_to_text(estimation)
  local lines = {}
  local est = estimation or models.Estimation.new()

  -- Type section
  table.insert(lines, "Type")
  table.insert(lines, string.format("  %s New work   %s Change   %s Bugfix   %s Research/Spike",
    checkbox(est.work_type == "new_work"),
    checkbox(est.work_type == "change"),
    checkbox(est.work_type == "bugfix"),
    checkbox(est.work_type == "research")))
  table.insert(lines, "")

  -- Assumptions section
  table.insert(lines, "Assumptions")
  if #est.assumptions > 0 then
    for _, assumption in ipairs(est.assumptions) do
      table.insert(lines, "  - " .. assumption)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Effort section
  table.insert(lines, "Effort (hours)")
  table.insert(lines, "Method:")
  table.insert(lines, string.format("  %s Similar work   %s 3-point   %s Gut feel",
    checkbox(est.effort.method == "similar_work"),
    checkbox(est.effort.method == "three_point"),
    checkbox(est.effort.method == "gut_feel")))
  table.insert(lines, "")
  table.insert(lines, "Estimate:")
  table.insert(lines, string.format("  - Base effort: %s",
    est.effort.base_hours > 0 and tostring(est.effort.base_hours) .. "h" or ""))
  table.insert(lines, string.format("  - Buffer: %s  (reason: %s)",
    est.effort.buffer_percent > 0 and tostring(est.effort.buffer_percent) .. "%" or "",
    est.effort.buffer_reason))
  table.insert(lines, string.format("  - Total: %s",
    est.effort.total_hours > 0 and tostring(est.effort.total_hours) .. "h" or ""))
  table.insert(lines, "")

  -- Confidence section
  table.insert(lines, "Confidence:")
  table.insert(lines, string.format("  %s Low  %s Med  %s High",
    checkbox(est.confidence == "low"),
    checkbox(est.confidence == "med"),
    checkbox(est.confidence == "high")))
  table.insert(lines, "")

  -- Schedule section
  table.insert(lines, "Schedule")
  table.insert(lines, "  - Start: " .. est.schedule.start_date)
  table.insert(lines, "  - Target finish: " .. est.schedule.target_finish)
  table.insert(lines, "  - Milestones:")
  if #est.schedule.milestones > 0 then
    for _, milestone in ipairs(est.schedule.milestones) do
      table.insert(lines, string.format("    - %s — %s", milestone.name or "", milestone.date or ""))
    end
  else
    table.insert(lines, "    - ")
  end
  table.insert(lines, "")

  -- Post-estimate notes section
  table.insert(lines, "Post-estimate notes")
  table.insert(lines, "  - What could make this smaller?")
  if #est.post_estimate_notes.could_be_smaller > 0 then
    for _, note in ipairs(est.post_estimate_notes.could_be_smaller) do
      table.insert(lines, "    - " .. note)
    end
  else
    table.insert(lines, "    - ")
  end
  table.insert(lines, "  - What could make this bigger?")
  if #est.post_estimate_notes.could_be_bigger > 0 then
    for _, note in ipairs(est.post_estimate_notes.could_be_bigger) do
      table.insert(lines, "    - " .. note)
    end
  else
    table.insert(lines, "    - ")
  end
  table.insert(lines, "  - What did I ignore / forget last time?")
  if #est.post_estimate_notes.ignored_last_time > 0 then
    for _, note in ipairs(est.post_estimate_notes.ignored_last_time) do
      table.insert(lines, "    - " .. note)
    end
  else
    table.insert(lines, "    - ")
  end

  return table.concat(lines, "\n")
end

-- Parse estimation from text
local function text_to_estimation(text)
  local est = {
    work_type = "",
    assumptions = {},
    effort = {
      method = "",
      base_hours = 0,
      buffer_percent = 0,
      buffer_reason = "",
      total_hours = 0,
    },
    confidence = "",
    schedule = {
      start_date = "",
      target_finish = "",
      milestones = {},
    },
    post_estimate_notes = {
      could_be_smaller = {},
      could_be_bigger = {},
      ignored_last_time = {},
    },
  }

  local current_section = nil
  local current_subsection = nil

  for line in text:gmatch("[^\r\n]*") do
    -- Check section headers FIRST (before content matchers)
    if line:match("^Type$") then
      current_section = "type"
      current_subsection = nil
    elseif line:match("^Assumptions$") then
      current_section = "assumptions"
      current_subsection = nil
    elseif line:match("^Effort") then
      current_section = "effort"
      current_subsection = nil
    elseif line:match("^Confidence:$") then
      current_section = "confidence"
      current_subsection = nil
    elseif line:match("^Schedule$") then
      current_section = "schedule"
      current_subsection = nil
    elseif line:match("^Post%-estimate notes$") then
      current_section = "post_estimate"
      current_subsection = nil

    -- Type section content
    elseif current_section == "type" and line:match("%[.%]") then
      local work_type_options = {
        { pattern = "New work", value = "new_work" },
        { pattern = "Change", value = "change" },
        { pattern = "Bugfix", value = "bugfix" },
        { pattern = "Research/Spike", value = "research" },
      }
      est.work_type = get_checked_value(line, work_type_options)

    -- Assumptions section content
    elseif current_section == "assumptions" and line:match("^%s+%-%s*(.*)$") then
      local assumption = vim.trim(line:match("^%s+%-%s*(.*)$"))
      if assumption ~= "" then
        table.insert(est.assumptions, assumption)
      end

    -- Effort section content
    elseif current_section == "effort" and line:match("^Method:") then
      current_subsection = "method"
    elseif current_section == "effort" and current_subsection == "method" and line:match("%[.%]") then
      local method_options = {
        { pattern = "Similar work", value = "similar_work" },
        { pattern = "3%-point", value = "three_point" },
        { pattern = "Gut feel", value = "gut_feel" },
      }
      est.effort.method = get_checked_value(line, method_options)
    elseif current_section == "effort" and line:match("^Estimate:") then
      current_subsection = "estimate"
    elseif current_section == "effort" and current_subsection == "estimate" then
      local base = line:match("Base effort:%s*(%d+)")
      if base then est.effort.base_hours = tonumber(base) or 0 end

      local buffer, reason = line:match("Buffer:%s*(%d+)%%%s*%(reason:%s*(.-)%)")
      if buffer then
        est.effort.buffer_percent = tonumber(buffer) or 0
        est.effort.buffer_reason = vim.trim(reason or "")
      end

      local total = line:match("Total:%s*(%d+)")
      if total then est.effort.total_hours = tonumber(total) or 0 end

    -- Confidence section content
    elseif current_section == "confidence" and line:match("%[.%]") then
      local conf_options = {
        { pattern = "Low", value = "low" },
        { pattern = "Med", value = "med" },
        { pattern = "High", value = "high" },
      }
      est.confidence = get_checked_value(line, conf_options)

    -- Schedule section content
    elseif current_section == "schedule" and line:match("Start:") then
      est.schedule.start_date = vim.trim(line:match("Start:%s*(.*)$") or "")
    elseif current_section == "schedule" and line:match("Target finish:") then
      est.schedule.target_finish = vim.trim(line:match("Target finish:%s*(.*)$") or "")
    elseif current_section == "schedule" and line:match("Milestones:") then
      current_subsection = "milestones"
    elseif current_section == "schedule" and current_subsection == "milestones" and line:match("^%s+%s+%-%s*(.*)$") then
      local milestone_text = vim.trim(line:match("^%s+%s+%-%s*(.*)$"))
      if milestone_text ~= "" then
        local name, date = milestone_text:match("(.-)%s*—%s*(.*)")
        if name then
          table.insert(est.schedule.milestones, { name = vim.trim(name), date = vim.trim(date or "") })
        else
          table.insert(est.schedule.milestones, { name = milestone_text, date = "" })
        end
      end

    -- Post-estimate notes section content
    elseif current_section == "post_estimate" and line:match("What could make this smaller") then
      current_subsection = "smaller"
    elseif current_section == "post_estimate" and line:match("What could make this bigger") then
      current_subsection = "bigger"
    elseif current_section == "post_estimate" and line:match("What did I ignore") then
      current_subsection = "ignored"
    elseif current_section == "post_estimate" and current_subsection and line:match("^%s+%s+%-%s*(.*)$") then
      local note = vim.trim(line:match("^%s+%s+%-%s*(.*)$"))
      if note ~= "" then
        if current_subsection == "smaller" then
          table.insert(est.post_estimate_notes.could_be_smaller, note)
        elseif current_subsection == "bigger" then
          table.insert(est.post_estimate_notes.could_be_bigger, note)
        elseif current_subsection == "ignored" then
          table.insert(est.post_estimate_notes.ignored_last_time, note)
        end
      end
    end
  end

  return models.Estimation.new(est)
end

-- Convert Task to editable text format
-- @param task: Task - The task to convert
-- @param node_type: string|nil - "Area", "Component", or "Job" (nil shows no estimation)
-- @return string - Human-readable text format
function M.task_to_text(task, node_type)
  local lines = {}

  -- Task header with ID
  table.insert(lines, string.format("── Task: %s ───────────────────", task.id or ""))
  table.insert(lines, "Name: " .. (task.name or ""))
  table.insert(lines, "")

  -- Details section
  table.insert(lines, "── Details ──────────────────────────")
  if task.details and task.details ~= "" then
    table.insert(lines, task.details)
  end
  table.insert(lines, "")

  -- Estimation section (only for Jobs)
  if node_type == "Job" then
    table.insert(lines, "── Estimation ───────────────────────")
    table.insert(lines, estimation_to_text(task.estimation))
    table.insert(lines, "")
  end

  -- Notes section (for migrated estimations or general notes)
  table.insert(lines, "── Notes ────────────────────────────")
  if task.notes and task.notes ~= "" then
    table.insert(lines, task.notes)
  end
  table.insert(lines, "")

  -- Tags section
  table.insert(lines, "── Tags ─────────────────────────────")
  if task.tags and #task.tags > 0 then
    table.insert(lines, table.concat(task.tags, ", "))
  end

  return table.concat(lines, "\n")
end

-- Parse text back to Task
-- @param text: string - Human-readable text format
-- @param node_type: string|nil - "Area", "Component", or "Job"
-- @return Task - Parsed task
function M.text_to_task(text, node_type)
  local id = ""
  local name = ""
  local details = ""
  local estimation = nil
  local notes = ""
  local tags = {}

  local current_section = nil
  local section_content = {}

  for line in text:gmatch("[^\r\n]*") do
    -- Check for task header
    local task_id = line:match("^── Task:%s*([^─]+)")
    if task_id then
      id = vim.trim(task_id)
      current_section = "header"
      section_content = {}
    elseif line:match("^── Details") then
      current_section = "details"
      section_content = {}
    elseif line:match("^── Estimation") then
      -- Save details before switching
      if current_section == "details" then
        details = table.concat(section_content, "\n")
      end
      current_section = "estimation"
      section_content = {}
    elseif line:match("^── Notes") then
      -- Save previous section
      if current_section == "details" then
        details = table.concat(section_content, "\n")
      elseif current_section == "estimation" then
        -- Parse estimation
        if node_type == "Job" then
          estimation = text_to_estimation(table.concat(section_content, "\n"))
        end
      end
      current_section = "notes"
      section_content = {}
    elseif line:match("^── Tags") then
      -- Save previous section
      if current_section == "details" then
        details = table.concat(section_content, "\n")
      elseif current_section == "estimation" then
        if node_type == "Job" then
          estimation = text_to_estimation(table.concat(section_content, "\n"))
        end
      elseif current_section == "notes" then
        notes = table.concat(section_content, "\n")
      end
      current_section = "tags"
      section_content = {}
    elseif current_section == "header" then
      -- Parse name
      local name_val = line:match("^Name:%s*(.*)$")
      if name_val then
        name = vim.trim(name_val)
      end
    elseif current_section == "details" then
      if line ~= "" or #section_content > 0 then
        table.insert(section_content, line)
      end
    elseif current_section == "estimation" then
      table.insert(section_content, line)
    elseif current_section == "notes" then
      if line ~= "" or #section_content > 0 then
        table.insert(section_content, line)
      end
    elseif current_section == "tags" then
      if line ~= "" then
        -- Parse comma-separated tags
        for tag in line:gmatch("[^,]+") do
          local trimmed = vim.trim(tag)
          if trimmed ~= "" then
            table.insert(tags, trimmed)
          end
        end
      end
    end
  end

  -- Handle final section
  if current_section == "details" then
    details = table.concat(section_content, "\n")
  elseif current_section == "estimation" then
    if node_type == "Job" then
      estimation = text_to_estimation(table.concat(section_content, "\n"))
    end
  elseif current_section == "notes" then
    notes = table.concat(section_content, "\n")
  end

  -- Trim trailing whitespace from multi-line content
  details = vim.trim(details)
  notes = vim.trim(notes)

  return models.Task.new(id, name, details, estimation, tags, notes)
end

return M
