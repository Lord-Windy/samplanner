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

-- Helper to normalize consecutive empty lines (collapse multiple empty lines into at most one)
local function normalize_empty_lines(lines)
  local result = {}
  local prev_empty = false

  for _, line in ipairs(lines) do
    local is_empty = (line == "")
    -- Only add this line if it's not empty, or if the previous line wasn't empty
    if not (is_empty and prev_empty) then
      table.insert(result, line)
    end
    prev_empty = is_empty
  end

  return result
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
  if est.assumptions and est.assumptions ~= "" then
    -- Output text as-is, just add indentation
    for line in est.assumptions:gmatch("[^\r\n]+") do
      table.insert(lines, "  " .. line)
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
  if est.post_estimate_notes.could_be_smaller and est.post_estimate_notes.could_be_smaller ~= "" then
    for line in est.post_estimate_notes.could_be_smaller:gmatch("[^\r\n]+") do
      table.insert(lines, "    " .. line)
    end
  else
    table.insert(lines, "    - ")
  end
  table.insert(lines, "  - What could make this bigger?")
  if est.post_estimate_notes.could_be_bigger and est.post_estimate_notes.could_be_bigger ~= "" then
    for line in est.post_estimate_notes.could_be_bigger:gmatch("[^\r\n]+") do
      table.insert(lines, "    " .. line)
    end
  else
    table.insert(lines, "    - ")
  end
  table.insert(lines, "  - What did I ignore / forget last time?")
  if est.post_estimate_notes.ignored_last_time and est.post_estimate_notes.ignored_last_time ~= "" then
    for line in est.post_estimate_notes.ignored_last_time:gmatch("[^\r\n]+") do
      table.insert(lines, "    " .. line)
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
    assumptions = "",
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
      could_be_smaller = "",
      could_be_bigger = "",
      ignored_last_time = "",
    },
  }

  local current_section = nil
  local current_subsection = nil
  local section_lines = {}  -- For capturing free-form sections

  -- Add newline to ensure last line is captured, then match lines
  for line in (text .. "\n"):gmatch("([^\r\n]*)\r?\n") do
    -- Check section headers FIRST (before content matchers)
    if line:match("^Type$") then
      current_section = "type"
      current_subsection = nil
      section_lines = {}
    elseif line:match("^Assumptions$") then
      current_section = "assumptions"
      current_subsection = nil
      section_lines = {}
    elseif line:match("^Effort") then
      -- Save previous section
      if current_section == "assumptions" and #section_lines > 0 then
        section_lines = normalize_empty_lines(section_lines)
        while #section_lines > 0 and section_lines[#section_lines] == "" do
          table.remove(section_lines)
        end
        while #section_lines > 0 and section_lines[1] == "" do
          table.remove(section_lines, 1)
        end
        est.assumptions = table.concat(section_lines, "\n")
      end
      current_section = "effort"
      current_subsection = nil
      section_lines = {}
    elseif line:match("^Confidence:$") then
      current_section = "confidence"
      current_subsection = nil
      section_lines = {}
    elseif line:match("^Schedule$") then
      current_section = "schedule"
      current_subsection = nil
      section_lines = {}
    elseif line:match("^Post%-estimate notes$") then
      current_section = "post_estimate"
      current_subsection = nil
      section_lines = {}

    -- Type section content
    elseif current_section == "type" and line:match("%[.%]") then
      local work_type_options = {
        { pattern = "New work", value = "new_work" },
        { pattern = "Change", value = "change" },
        { pattern = "Bugfix", value = "bugfix" },
        { pattern = "Research/Spike", value = "research" },
      }
      est.work_type = get_checked_value(line, work_type_options)

    -- Assumptions section content - capture ALL indented text
    elseif current_section == "assumptions" and line:match("^%s+") then
      local content = line:match("^%s+(.*)$")
      if content and content ~= "" then
        table.insert(section_lines, content)
      elseif #section_lines > 0 then
        table.insert(section_lines, "")
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
      section_lines = {}
    elseif current_section == "post_estimate" and line:match("What could make this bigger") then
      -- Save previous subsection
      if current_subsection == "smaller" and #section_lines > 0 then
        section_lines = normalize_empty_lines(section_lines)
        while #section_lines > 0 and section_lines[#section_lines] == "" do
          table.remove(section_lines)
        end
        while #section_lines > 0 and section_lines[1] == "" do
          table.remove(section_lines, 1)
        end
        est.post_estimate_notes.could_be_smaller = table.concat(section_lines, "\n")
      end
      current_subsection = "bigger"
      section_lines = {}
    elseif current_section == "post_estimate" and line:match("What did I ignore") then
      -- Save previous subsection
      if current_subsection == "bigger" and #section_lines > 0 then
        section_lines = normalize_empty_lines(section_lines)
        while #section_lines > 0 and section_lines[#section_lines] == "" do
          table.remove(section_lines)
        end
        while #section_lines > 0 and section_lines[1] == "" do
          table.remove(section_lines, 1)
        end
        est.post_estimate_notes.could_be_bigger = table.concat(section_lines, "\n")
      end
      current_subsection = "ignored"
      section_lines = {}
    elseif current_section == "post_estimate" and current_subsection and line:match("^%s+%s+") then
      -- Capture ALL indented text (4+ spaces)
      local content = line:match("^%s+%s+(.*)$")
      if content and content ~= "" then
        table.insert(section_lines, content)
      elseif #section_lines > 0 then
        table.insert(section_lines, "")
      end
    end
  end

  -- Save final post_estimate subsection
  if current_section == "post_estimate" and current_subsection and #section_lines > 0 then
    section_lines = normalize_empty_lines(section_lines)
    while #section_lines > 0 and section_lines[#section_lines] == "" do
      table.remove(section_lines)
    end
    while #section_lines > 0 and section_lines[1] == "" do
      table.remove(section_lines, 1)
    end
    local content = table.concat(section_lines, "\n")
    if current_subsection == "smaller" then
      est.post_estimate_notes.could_be_smaller = content
    elseif current_subsection == "bigger" then
      est.post_estimate_notes.could_be_bigger = content
    elseif current_subsection == "ignored" then
      est.post_estimate_notes.ignored_last_time = content
    end
  end

  return models.Estimation.new(est)
end

-- Convert JobDetails to text format
local function job_details_to_text(job_details)
  local lines = {}
  local jd = job_details or models.JobDetails.new()

  -- Context / Why section
  table.insert(lines, "Context / Why")
  if jd.context_why and jd.context_why ~= "" then
    table.insert(lines, jd.context_why)
  else
    table.insert(lines, "")
  end
  table.insert(lines, "")

  -- Completion status
  table.insert(lines, string.format("%s Completed", checkbox(jd.completed)))
  table.insert(lines, "")

  -- Outcome / Definition of Done section
  table.insert(lines, "Outcome / Definition of Done")
  if jd.outcome_dod and jd.outcome_dod ~= "" then
    -- Output text as-is, just add indentation
    for line in jd.outcome_dod:gmatch("[^\r\n]+") do
      table.insert(lines, "  " .. line)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Scope section
  table.insert(lines, "Scope")
  table.insert(lines, "  In scope:")
  if jd.scope_in and jd.scope_in ~= "" then
    -- Output text as-is with 4-space indentation
    for line in jd.scope_in:gmatch("[^\r\n]+") do
      table.insert(lines, "    " .. line)
    end
  else
    table.insert(lines, "    - ")
  end
  table.insert(lines, "  Out of scope:")
  if jd.scope_out and jd.scope_out ~= "" then
    -- Output text as-is with 4-space indentation
    for line in jd.scope_out:gmatch("[^\r\n]+") do
      table.insert(lines, "    " .. line)
    end
  else
    table.insert(lines, "    - ")
  end
  table.insert(lines, "")

  -- Requirements / Constraints section
  table.insert(lines, "Requirements / Constraints")
  if jd.requirements_constraints and jd.requirements_constraints ~= "" then
    -- Output text as-is, just add indentation
    for line in jd.requirements_constraints:gmatch("[^\r\n]+") do
      table.insert(lines, "  " .. line)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Dependencies section
  table.insert(lines, "Dependencies")
  if jd.dependencies and jd.dependencies ~= "" then
    -- Output text as-is, just add indentation
    for line in jd.dependencies:gmatch("[^\r\n]+") do
      table.insert(lines, "  " .. line)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Approach section
  table.insert(lines, "Approach (brief plan)")
  if jd.approach and jd.approach ~= "" then
    -- Output text as-is, just add indentation
    for line in jd.approach:gmatch("[^\r\n]+") do
      table.insert(lines, "  " .. line)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Risks section
  table.insert(lines, "Risks")
  if jd.risks and jd.risks ~= "" then
    -- Output text as-is, just add indentation
    for line in jd.risks:gmatch("[^\r\n]+") do
      table.insert(lines, "  " .. line)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Validation / Test Plan section
  table.insert(lines, "Validation / Test Plan")
  if jd.validation_test_plan and jd.validation_test_plan ~= "" then
    -- Output text as-is, just add indentation
    for line in jd.validation_test_plan:gmatch("[^\r\n]+") do
      table.insert(lines, "  " .. line)
    end
  else
    table.insert(lines, "  - ")
  end

  return table.concat(lines, "\n")
end

-- Parse JobDetails from text
local function text_to_job_details(text)
  local jd = {
    context_why = "",
    outcome_dod = "",
    scope_in = "",
    scope_out = "",
    requirements_constraints = "",
    dependencies = "",
    approach = "",
    risks = "",
    validation_test_plan = "",
    completed = false,
  }

  local current_section = nil
  local current_subsection = nil
  local context_lines = {}
  local section_lines = {}  -- For capturing free-form sections

  -- Add newline to ensure last line is captured, then match lines
  for line in (text .. "\n"):gmatch("([^\r\n]*)\r?\n") do
    -- Check section headers
    if line:match("^Context / Why$") then
      current_section = "context"
      current_subsection = nil
      context_lines = {}
    elseif line:match("^%[.%]%s+Completed$") then
      -- Parse completion checkbox
      jd.completed = line:match("^%[x%]") or line:match("^%[X%]")
      if jd.completed then
        jd.completed = true
      else
        jd.completed = false
      end
    elseif line:match("^Outcome / Definition of Done$") then
      -- Save context before switching
      if current_section == "context" and #context_lines > 0 then
        -- Normalize consecutive empty lines
        context_lines = normalize_empty_lines(context_lines)
        -- Remove trailing empty lines
        while #context_lines > 0 and context_lines[#context_lines] == "" do
          table.remove(context_lines)
        end
        -- Remove leading empty lines
        while #context_lines > 0 and context_lines[1] == "" do
          table.remove(context_lines, 1)
        end
        jd.context_why = table.concat(context_lines, "\n")
      end
      current_section = "outcome"
      current_subsection = nil
      section_lines = {}  -- Reset for new section
    elseif line:match("^Scope$") then
      -- Save previous section
      if current_section == "outcome" and #section_lines > 0 then
        section_lines = normalize_empty_lines(section_lines)
        while #section_lines > 0 and section_lines[#section_lines] == "" do
          table.remove(section_lines)
        end
        while #section_lines > 0 and section_lines[1] == "" do
          table.remove(section_lines, 1)
        end
        jd.outcome_dod = table.concat(section_lines, "\n")
      end
      current_section = "scope"
      current_subsection = nil
      section_lines = {}
    elseif line:match("^Requirements / Constraints$") then
      -- Save previous scope subsection
      if current_section == "scope" and current_subsection == "out" and #section_lines > 0 then
        section_lines = normalize_empty_lines(section_lines)
        while #section_lines > 0 and section_lines[#section_lines] == "" do
          table.remove(section_lines)
        end
        while #section_lines > 0 and section_lines[1] == "" do
          table.remove(section_lines, 1)
        end
        jd.scope_out = table.concat(section_lines, "\n")
      end
      current_section = "requirements"
      current_subsection = nil
      section_lines = {}
    elseif line:match("^Dependencies$") then
      -- Save previous section
      if current_section == "requirements" and #section_lines > 0 then
        section_lines = normalize_empty_lines(section_lines)
        while #section_lines > 0 and section_lines[#section_lines] == "" do
          table.remove(section_lines)
        end
        while #section_lines > 0 and section_lines[1] == "" do
          table.remove(section_lines, 1)
        end
        jd.requirements_constraints = table.concat(section_lines, "\n")
      end
      current_section = "dependencies"
      current_subsection = nil
      section_lines = {}
    elseif line:match("^Approach") then
      -- Save previous section
      if current_section == "dependencies" and #section_lines > 0 then
        section_lines = normalize_empty_lines(section_lines)
        while #section_lines > 0 and section_lines[#section_lines] == "" do
          table.remove(section_lines)
        end
        while #section_lines > 0 and section_lines[1] == "" do
          table.remove(section_lines, 1)
        end
        jd.dependencies = table.concat(section_lines, "\n")
      end
      current_section = "approach"
      current_subsection = nil
      section_lines = {}
    elseif line:match("^Risks$") then
      -- Save previous section
      if current_section == "approach" and #section_lines > 0 then
        section_lines = normalize_empty_lines(section_lines)
        while #section_lines > 0 and section_lines[#section_lines] == "" do
          table.remove(section_lines)
        end
        while #section_lines > 0 and section_lines[1] == "" do
          table.remove(section_lines, 1)
        end
        jd.approach = table.concat(section_lines, "\n")
      end
      current_section = "risks"
      current_subsection = nil
      section_lines = {}
    elseif line:match("^Validation / Test Plan$") then
      -- Save previous section
      if current_section == "risks" and #section_lines > 0 then
        section_lines = normalize_empty_lines(section_lines)
        while #section_lines > 0 and section_lines[#section_lines] == "" do
          table.remove(section_lines)
        end
        while #section_lines > 0 and section_lines[1] == "" do
          table.remove(section_lines, 1)
        end
        jd.risks = table.concat(section_lines, "\n")
      end
      current_section = "validation"
      current_subsection = nil
      section_lines = {}

    -- Context section content (capture everything until next section)
    elseif current_section == "context" then
      -- Only add non-empty lines or preserve internal empty lines
      if line ~= "" then
        table.insert(context_lines, line)
      elseif #context_lines > 0 then
        -- Mark that we saw an empty line, but don't add it yet
        -- This prevents trailing empty lines from being added
        table.insert(context_lines, "")
      end

    -- Outcome section content - capture ALL lines (free-form text)
    elseif current_section == "outcome" and line:match("^%s+") then
      -- Capture any indented line (with or without bullets)
      local content = line:match("^%s+(.*)$")
      if content and content ~= "" then
        table.insert(section_lines, content)
      elseif #section_lines > 0 then
        -- Preserve internal empty lines
        table.insert(section_lines, "")
      end

    -- Scope section content
    elseif current_section == "scope" and line:match("^%s+In scope:") then
      current_subsection = "in"
      section_lines = {}
    elseif current_section == "scope" and line:match("^%s+Out of scope:") then
      -- Save previous subsection
      if current_subsection == "in" and #section_lines > 0 then
        section_lines = normalize_empty_lines(section_lines)
        while #section_lines > 0 and section_lines[#section_lines] == "" do
          table.remove(section_lines)
        end
        while #section_lines > 0 and section_lines[1] == "" do
          table.remove(section_lines, 1)
        end
        jd.scope_in = table.concat(section_lines, "\n")
      end
      current_subsection = "out"
      section_lines = {}
    elseif current_section == "scope" and current_subsection and line:match("^%s+%s+%s+%s+") then
      -- Capture ALL text indented 4+ spaces
      local content = line:match("^%s+%s+%s+%s+(.*)$")
      if content and content ~= "" then
        table.insert(section_lines, content)
      elseif #section_lines > 0 then
        table.insert(section_lines, "")
      end

    -- Requirements section content - capture ALL indented text
    elseif current_section == "requirements" and line:match("^%s+") then
      local content = line:match("^%s+(.*)$")
      if content and content ~= "" then
        table.insert(section_lines, content)
      elseif #section_lines > 0 then
        table.insert(section_lines, "")
      end

    -- Dependencies section content - capture ALL indented text
    elseif current_section == "dependencies" and line:match("^%s+") then
      local content = line:match("^%s+(.*)$")
      if content and content ~= "" then
        table.insert(section_lines, content)
      elseif #section_lines > 0 then
        table.insert(section_lines, "")
      end

    -- Approach section content - capture ALL indented text
    elseif current_section == "approach" and line:match("^%s+") then
      local content = line:match("^%s+(.*)$")
      if content and content ~= "" then
        table.insert(section_lines, content)
      elseif #section_lines > 0 then
        table.insert(section_lines, "")
      end

    -- Risks section content - capture ALL indented text
    elseif current_section == "risks" and line:match("^%s+") then
      local content = line:match("^%s+(.*)$")
      if content and content ~= "" then
        table.insert(section_lines, content)
      elseif #section_lines > 0 then
        table.insert(section_lines, "")
      end

    -- Validation section content - capture ALL indented text
    elseif current_section == "validation" and line:match("^%s+") then
      local content = line:match("^%s+(.*)$")
      if content and content ~= "" then
        table.insert(section_lines, content)
      elseif #section_lines > 0 then
        table.insert(section_lines, "")
      end
    end
  end

  -- Save final section if any
  if #section_lines > 0 then
    section_lines = normalize_empty_lines(section_lines)
    while #section_lines > 0 and section_lines[#section_lines] == "" do
      table.remove(section_lines)
    end
    while #section_lines > 0 and section_lines[1] == "" do
      table.remove(section_lines, 1)
    end
    local content = table.concat(section_lines, "\n")

    if current_section == "outcome" then
      jd.outcome_dod = content
    elseif current_section == "scope" then
      -- Handle scope subsections
      if current_subsection == "in" then
        jd.scope_in = content
      elseif current_subsection == "out" then
        jd.scope_out = content
      end
    elseif current_section == "requirements" then
      jd.requirements_constraints = content
    elseif current_section == "dependencies" then
      jd.dependencies = content
    elseif current_section == "approach" then
      jd.approach = content
    elseif current_section == "risks" then
      jd.risks = content
    elseif current_section == "validation" then
      jd.validation_test_plan = content
    end
  end

  -- Handle final context section
  if current_section == "context" and #context_lines > 0 then
    -- Normalize consecutive empty lines
    context_lines = normalize_empty_lines(context_lines)
    -- Remove trailing empty lines
    while #context_lines > 0 and context_lines[#context_lines] == "" do
      table.remove(context_lines)
    end
    -- Remove leading empty lines
    while #context_lines > 0 and context_lines[1] == "" do
      table.remove(context_lines, 1)
    end
    jd.context_why = vim.trim(table.concat(context_lines, "\n"))
  end

  return models.JobDetails.new(jd)
end

-- Convert ComponentDetails to text format
local function component_details_to_text(component_details)
  local lines = {}
  local cd = component_details or models.ComponentDetails.new()

  -- Purpose / What It Is section
  table.insert(lines, "Purpose / What It Is")
  if cd.purpose and cd.purpose ~= "" then
    table.insert(lines, cd.purpose)
  else
    table.insert(lines, "")
  end
  table.insert(lines, "")

  -- Capabilities / Features section
  table.insert(lines, "Capabilities / Features")
  if cd.capabilities and cd.capabilities ~= "" then
    -- Output text as-is, just add indentation
    for line in cd.capabilities:gmatch("[^\r\n]+") do
      table.insert(lines, "  " .. line)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Acceptance Criteria section
  table.insert(lines, "Acceptance Criteria")
  if cd.acceptance_criteria and cd.acceptance_criteria ~= "" then
    for line in cd.acceptance_criteria:gmatch("[^\r\n]+") do
      table.insert(lines, "  " .. line)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Architecture / Design section
  table.insert(lines, "Architecture / Design")
  if cd.architecture_design and cd.architecture_design ~= "" then
    for line in cd.architecture_design:gmatch("[^\r\n]+") do
      table.insert(lines, "  " .. line)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Interfaces / Integration Points section
  table.insert(lines, "Interfaces / Integration Points")
  if cd.interfaces_integration and cd.interfaces_integration ~= "" then
    for line in cd.interfaces_integration:gmatch("[^\r\n]+") do
      table.insert(lines, "  " .. line)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Quality Attributes section
  table.insert(lines, "Quality Attributes")
  if cd.quality_attributes and cd.quality_attributes ~= "" then
    for line in cd.quality_attributes:gmatch("[^\r\n]+") do
      table.insert(lines, "  " .. line)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Related Components section
  table.insert(lines, "Related Components")
  if cd.related_components and cd.related_components ~= "" then
    for line in cd.related_components:gmatch("[^\r\n]+") do
      table.insert(lines, "  " .. line)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Other section
  table.insert(lines, "Other")
  if cd.other and cd.other ~= "" then
    table.insert(lines, cd.other)
  else
    table.insert(lines, "")
  end

  return table.concat(lines, "\n")
end

-- Parse ComponentDetails from text
local function text_to_component_details(text)
  local cd = {
    purpose = "",
    capabilities = "",
    acceptance_criteria = "",
    architecture_design = "",
    interfaces_integration = "",
    quality_attributes = "",
    related_components = "",
    other = "",
  }

  local current_section = nil
  local purpose_lines = {}
  local other_lines = {}
  local section_lines = {}  -- For capturing free-form sections

  -- Add newline to ensure last line is captured, then match lines
  for line in (text .. "\n"):gmatch("([^\r\n]*)\r?\n") do
    -- Check section headers
    if line:match("^Purpose / What It Is$") then
      current_section = "purpose"
      purpose_lines = {}
    elseif line:match("^Capabilities / Features$") then
      -- Save purpose before switching
      if current_section == "purpose" and #purpose_lines > 0 then
        purpose_lines = normalize_empty_lines(purpose_lines)
        while #purpose_lines > 0 and purpose_lines[#purpose_lines] == "" do
          table.remove(purpose_lines)
        end
        while #purpose_lines > 0 and purpose_lines[1] == "" do
          table.remove(purpose_lines, 1)
        end
        cd.purpose = table.concat(purpose_lines, "\n")
      end
      current_section = "capabilities"
      section_lines = {}
    elseif line:match("^Acceptance Criteria$") then
      -- Save previous section
      if current_section == "capabilities" and #section_lines > 0 then
        section_lines = normalize_empty_lines(section_lines)
        while #section_lines > 0 and section_lines[#section_lines] == "" do
          table.remove(section_lines)
        end
        while #section_lines > 0 and section_lines[1] == "" do
          table.remove(section_lines, 1)
        end
        cd.capabilities = table.concat(section_lines, "\n")
      end
      current_section = "acceptance_criteria"
      section_lines = {}
    elseif line:match("^Architecture / Design$") then
      -- Save previous section
      if current_section == "acceptance_criteria" and #section_lines > 0 then
        section_lines = normalize_empty_lines(section_lines)
        while #section_lines > 0 and section_lines[#section_lines] == "" do
          table.remove(section_lines)
        end
        while #section_lines > 0 and section_lines[1] == "" do
          table.remove(section_lines, 1)
        end
        cd.acceptance_criteria = table.concat(section_lines, "\n")
      end
      current_section = "architecture"
      section_lines = {}
    elseif line:match("^Interfaces / Integration Points$") then
      -- Save previous section
      if current_section == "architecture" and #section_lines > 0 then
        section_lines = normalize_empty_lines(section_lines)
        while #section_lines > 0 and section_lines[#section_lines] == "" do
          table.remove(section_lines)
        end
        while #section_lines > 0 and section_lines[1] == "" do
          table.remove(section_lines, 1)
        end
        cd.architecture_design = table.concat(section_lines, "\n")
      end
      current_section = "interfaces"
      section_lines = {}
    elseif line:match("^Quality Attributes$") then
      -- Save previous section
      if current_section == "interfaces" and #section_lines > 0 then
        section_lines = normalize_empty_lines(section_lines)
        while #section_lines > 0 and section_lines[#section_lines] == "" do
          table.remove(section_lines)
        end
        while #section_lines > 0 and section_lines[1] == "" do
          table.remove(section_lines, 1)
        end
        cd.interfaces_integration = table.concat(section_lines, "\n")
      end
      current_section = "quality_attributes"
      section_lines = {}
    elseif line:match("^Related Components$") then
      -- Save previous section
      if current_section == "quality_attributes" and #section_lines > 0 then
        section_lines = normalize_empty_lines(section_lines)
        while #section_lines > 0 and section_lines[#section_lines] == "" do
          table.remove(section_lines)
        end
        while #section_lines > 0 and section_lines[1] == "" do
          table.remove(section_lines, 1)
        end
        cd.quality_attributes = table.concat(section_lines, "\n")
      end
      current_section = "related_components"
      section_lines = {}
    elseif line:match("^Other$") then
      -- Save previous section
      if current_section == "related_components" and #section_lines > 0 then
        section_lines = normalize_empty_lines(section_lines)
        while #section_lines > 0 and section_lines[#section_lines] == "" do
          table.remove(section_lines)
        end
        while #section_lines > 0 and section_lines[1] == "" do
          table.remove(section_lines, 1)
        end
        cd.related_components = table.concat(section_lines, "\n")
      end
      current_section = "other"
      other_lines = {}

    -- Purpose section content (capture everything until next section)
    elseif current_section == "purpose" then
      -- Skip leading empty lines, but preserve internal ones
      if line ~= "" then
        table.insert(purpose_lines, line)
      elseif #purpose_lines > 0 then
        table.insert(purpose_lines, "")
      end

    -- Section content - capture ALL indented text
    elseif (current_section == "capabilities" or current_section == "acceptance_criteria" or
            current_section == "architecture" or current_section == "interfaces" or
            current_section == "quality_attributes" or current_section == "related_components") and line:match("^%s+") then
      local content = line:match("^%s+(.*)$")
      if content and content ~= "" then
        table.insert(section_lines, content)
      elseif #section_lines > 0 then
        table.insert(section_lines, "")
      end

    -- Other section content (capture everything)
    elseif current_section == "other" then
      -- Skip leading empty lines, but preserve internal ones
      if line ~= "" then
        table.insert(other_lines, line)
      elseif #other_lines > 0 then
        table.insert(other_lines, "")
      end
    end
  end

  -- Handle final sections
  if current_section == "purpose" and #purpose_lines > 0 then
    purpose_lines = normalize_empty_lines(purpose_lines)
    while #purpose_lines > 0 and purpose_lines[#purpose_lines] == "" do
      table.remove(purpose_lines)
    end
    while #purpose_lines > 0 and purpose_lines[1] == "" do
      table.remove(purpose_lines, 1)
    end
    cd.purpose = vim.trim(table.concat(purpose_lines, "\n"))
  elseif (current_section == "capabilities" or current_section == "acceptance_criteria" or
          current_section == "architecture" or current_section == "interfaces" or
          current_section == "quality_attributes" or current_section == "related_components") and #section_lines > 0 then
    section_lines = normalize_empty_lines(section_lines)
    while #section_lines > 0 and section_lines[#section_lines] == "" do
      table.remove(section_lines)
    end
    while #section_lines > 0 and section_lines[1] == "" do
      table.remove(section_lines, 1)
    end
    local content = table.concat(section_lines, "\n")
    if current_section == "capabilities" then
      cd.capabilities = content
    elseif current_section == "acceptance_criteria" then
      cd.acceptance_criteria = content
    elseif current_section == "architecture" then
      cd.architecture_design = content
    elseif current_section == "interfaces" then
      cd.interfaces_integration = content
    elseif current_section == "quality_attributes" then
      cd.quality_attributes = content
    elseif current_section == "related_components" then
      cd.related_components = content
    end
  elseif current_section == "other" and #other_lines > 0 then
    other_lines = normalize_empty_lines(other_lines)
    while #other_lines > 0 and other_lines[#other_lines] == "" do
      table.remove(other_lines)
    end
    while #other_lines > 0 and other_lines[1] == "" do
      table.remove(other_lines, 1)
    end
    cd.other = vim.trim(table.concat(other_lines, "\n"))
  end

  return models.ComponentDetails.new(cd)
end

-- Convert AreaDetails to text format
local function area_details_to_text(area_details)
  local lines = {}
  local ad = area_details or models.AreaDetails.new()

  -- Vision / Purpose section
  table.insert(lines, "Vision / Purpose")
  if ad.vision_purpose and ad.vision_purpose ~= "" then
    table.insert(lines, ad.vision_purpose)
  else
    table.insert(lines, "")
  end
  table.insert(lines, "")

  -- Goals / Objectives section
  table.insert(lines, "Goals / Objectives")
  if ad.goals_objectives and ad.goals_objectives ~= "" then
    for line in ad.goals_objectives:gmatch("[^\r\n]+") do
      table.insert(lines, "  " .. line)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Scope / Boundaries section
  table.insert(lines, "Scope / Boundaries")
  if ad.scope_boundaries and ad.scope_boundaries ~= "" then
    for line in ad.scope_boundaries:gmatch("[^\r\n]+") do
      table.insert(lines, "  " .. line)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Key Components section
  table.insert(lines, "Key Components")
  if ad.key_components and ad.key_components ~= "" then
    for line in ad.key_components:gmatch("[^\r\n]+") do
      table.insert(lines, "  " .. line)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Success Metrics / KPIs section
  table.insert(lines, "Success Metrics / KPIs")
  if ad.success_metrics and ad.success_metrics ~= "" then
    for line in ad.success_metrics:gmatch("[^\r\n]+") do
      table.insert(lines, "  " .. line)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Stakeholders section
  table.insert(lines, "Stakeholders")
  if ad.stakeholders and ad.stakeholders ~= "" then
    for line in ad.stakeholders:gmatch("[^\r\n]+") do
      table.insert(lines, "  " .. line)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Dependencies / Constraints section
  table.insert(lines, "Dependencies / Constraints")
  if ad.dependencies_constraints and ad.dependencies_constraints ~= "" then
    for line in ad.dependencies_constraints:gmatch("[^\r\n]+") do
      table.insert(lines, "  " .. line)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Strategic Context section
  table.insert(lines, "Strategic Context")
  if ad.strategic_context and ad.strategic_context ~= "" then
    table.insert(lines, ad.strategic_context)
  else
    table.insert(lines, "")
  end

  return table.concat(lines, "\n")
end

-- Parse AreaDetails from text
local function text_to_area_details(text)
  local ad = {
    vision_purpose = "",
    goals_objectives = "",
    scope_boundaries = "",
    key_components = "",
    success_metrics = "",
    stakeholders = "",
    dependencies_constraints = "",
    strategic_context = "",
  }

  local current_section = nil
  local vision_lines = {}
  local context_lines = {}
  local section_lines = {}  -- For capturing free-form sections

  -- Add newline to ensure last line is captured, then match lines
  for line in (text .. "\n"):gmatch("([^\r\n]*)\r?\n") do
    -- Check section headers
    if line:match("^Vision / Purpose$") then
      current_section = "vision"
      vision_lines = {}
    elseif line:match("^Goals / Objectives$") then
      -- Save vision before switching
      if current_section == "vision" and #vision_lines > 0 then
        vision_lines = normalize_empty_lines(vision_lines)
        while #vision_lines > 0 and vision_lines[#vision_lines] == "" do
          table.remove(vision_lines)
        end
        while #vision_lines > 0 and vision_lines[1] == "" do
          table.remove(vision_lines, 1)
        end
        ad.vision_purpose = table.concat(vision_lines, "\n")
      end
      current_section = "goals"
      section_lines = {}
    elseif line:match("^Scope / Boundaries$") then
      -- Save previous section
      if current_section == "goals" and #section_lines > 0 then
        section_lines = normalize_empty_lines(section_lines)
        while #section_lines > 0 and section_lines[#section_lines] == "" do
          table.remove(section_lines)
        end
        while #section_lines > 0 and section_lines[1] == "" do
          table.remove(section_lines, 1)
        end
        ad.goals_objectives = table.concat(section_lines, "\n")
      end
      current_section = "scope"
      section_lines = {}
    elseif line:match("^Key Components$") then
      -- Save previous section
      if current_section == "scope" and #section_lines > 0 then
        section_lines = normalize_empty_lines(section_lines)
        while #section_lines > 0 and section_lines[#section_lines] == "" do
          table.remove(section_lines)
        end
        while #section_lines > 0 and section_lines[1] == "" do
          table.remove(section_lines, 1)
        end
        ad.scope_boundaries = table.concat(section_lines, "\n")
      end
      current_section = "components"
      section_lines = {}
    elseif line:match("^Success Metrics / KPIs$") then
      -- Save previous section
      if current_section == "components" and #section_lines > 0 then
        section_lines = normalize_empty_lines(section_lines)
        while #section_lines > 0 and section_lines[#section_lines] == "" do
          table.remove(section_lines)
        end
        while #section_lines > 0 and section_lines[1] == "" do
          table.remove(section_lines, 1)
        end
        ad.key_components = table.concat(section_lines, "\n")
      end
      current_section = "metrics"
      section_lines = {}
    elseif line:match("^Stakeholders$") then
      -- Save previous section
      if current_section == "metrics" and #section_lines > 0 then
        section_lines = normalize_empty_lines(section_lines)
        while #section_lines > 0 and section_lines[#section_lines] == "" do
          table.remove(section_lines)
        end
        while #section_lines > 0 and section_lines[1] == "" do
          table.remove(section_lines, 1)
        end
        ad.success_metrics = table.concat(section_lines, "\n")
      end
      current_section = "stakeholders"
      section_lines = {}
    elseif line:match("^Dependencies / Constraints$") then
      -- Save previous section
      if current_section == "stakeholders" and #section_lines > 0 then
        section_lines = normalize_empty_lines(section_lines)
        while #section_lines > 0 and section_lines[#section_lines] == "" do
          table.remove(section_lines)
        end
        while #section_lines > 0 and section_lines[1] == "" do
          table.remove(section_lines, 1)
        end
        ad.stakeholders = table.concat(section_lines, "\n")
      end
      current_section = "dependencies"
      section_lines = {}
    elseif line:match("^Strategic Context$") then
      -- Save previous section
      if current_section == "dependencies" and #section_lines > 0 then
        section_lines = normalize_empty_lines(section_lines)
        while #section_lines > 0 and section_lines[#section_lines] == "" do
          table.remove(section_lines)
        end
        while #section_lines > 0 and section_lines[1] == "" do
          table.remove(section_lines, 1)
        end
        ad.dependencies_constraints = table.concat(section_lines, "\n")
      end
      current_section = "context"
      context_lines = {}

    -- Vision section content (capture everything until next section)
    elseif current_section == "vision" then
      if line ~= "" then
        table.insert(vision_lines, line)
      elseif #vision_lines > 0 then
        table.insert(vision_lines, "")
      end

    -- Section content - capture ALL indented text
    elseif (current_section == "goals" or current_section == "scope" or
            current_section == "components" or current_section == "metrics" or
            current_section == "stakeholders" or current_section == "dependencies") and line:match("^%s+") then
      local content = line:match("^%s+(.*)$")
      if content and content ~= "" then
        table.insert(section_lines, content)
      elseif #section_lines > 0 then
        table.insert(section_lines, "")
      end

    -- Strategic Context section content (capture everything)
    elseif current_section == "context" then
      -- Skip leading empty lines, but preserve internal ones
      if line ~= "" then
        table.insert(context_lines, line)
      elseif #context_lines > 0 then
        table.insert(context_lines, "")
      end
    end
  end

  -- Handle final sections
  if current_section == "vision" and #vision_lines > 0 then
    vision_lines = normalize_empty_lines(vision_lines)
    while #vision_lines > 0 and vision_lines[#vision_lines] == "" do
      table.remove(vision_lines)
    end
    while #vision_lines > 0 and vision_lines[1] == "" do
      table.remove(vision_lines, 1)
    end
    ad.vision_purpose = vim.trim(table.concat(vision_lines, "\n"))
  elseif (current_section == "goals" or current_section == "scope" or
          current_section == "components" or current_section == "metrics" or
          current_section == "stakeholders" or current_section == "dependencies") and #section_lines > 0 then
    section_lines = normalize_empty_lines(section_lines)
    while #section_lines > 0 and section_lines[#section_lines] == "" do
      table.remove(section_lines)
    end
    while #section_lines > 0 and section_lines[1] == "" do
      table.remove(section_lines, 1)
    end
    local content = table.concat(section_lines, "\n")
    if current_section == "goals" then
      ad.goals_objectives = content
    elseif current_section == "scope" then
      ad.scope_boundaries = content
    elseif current_section == "components" then
      ad.key_components = content
    elseif current_section == "metrics" then
      ad.success_metrics = content
    elseif current_section == "stakeholders" then
      ad.stakeholders = content
    elseif current_section == "dependencies" then
      ad.dependencies_constraints = content
    end
  elseif current_section == "context" and #context_lines > 0 then
    context_lines = normalize_empty_lines(context_lines)
    while #context_lines > 0 and context_lines[#context_lines] == "" do
      table.remove(context_lines)
    end
    while #context_lines > 0 and context_lines[1] == "" do
      table.remove(context_lines, 1)
    end
    ad.strategic_context = vim.trim(table.concat(context_lines, "\n"))
  end

  return models.AreaDetails.new(ad)
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
  if node_type == "Job" then
    -- For Jobs, use structured JobDetails format
    if type(task.details) == "table" then
      table.insert(lines, job_details_to_text(task.details))
    else
      -- If somehow still a string, show it (shouldn't happen with migration)
      if task.details and task.details ~= "" then
        table.insert(lines, task.details)
      end
    end
  elseif node_type == "Component" then
    -- For Components, use structured ComponentDetails format
    if type(task.details) == "table" then
      table.insert(lines, component_details_to_text(task.details))
    else
      -- If somehow still a string, show it (shouldn't happen with migration)
      if task.details and task.details ~= "" then
        table.insert(lines, task.details)
      end
    end
  elseif node_type == "Area" then
    -- For Areas, use structured AreaDetails format
    if type(task.details) == "table" then
      table.insert(lines, area_details_to_text(task.details))
    else
      -- If somehow still a string, show it (shouldn't happen with migration)
      if task.details and task.details ~= "" then
        table.insert(lines, task.details)
      end
    end
  else
    -- For unknown types, show as plain text
    if task.details and task.details ~= "" then
      table.insert(lines, task.details)
    end
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

  -- Add newline to ensure last line is captured, then match lines
  for line in (text .. "\n"):gmatch("([^\r\n]*)\r?\n") do
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
        if node_type == "Job" then
          details = text_to_job_details(table.concat(section_content, "\n"))
        elseif node_type == "Component" then
          details = text_to_component_details(table.concat(section_content, "\n"))
        elseif node_type == "Area" then
          details = text_to_area_details(table.concat(section_content, "\n"))
        else
          details = table.concat(section_content, "\n")
        end
      end
      current_section = "estimation"
      section_content = {}
    elseif line:match("^── Notes") then
      -- Save previous section
      if current_section == "details" then
        if node_type == "Job" then
          details = text_to_job_details(table.concat(section_content, "\n"))
        elseif node_type == "Component" then
          details = text_to_component_details(table.concat(section_content, "\n"))
        elseif node_type == "Area" then
          details = text_to_area_details(table.concat(section_content, "\n"))
        else
          details = table.concat(section_content, "\n")
        end
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
        if node_type == "Job" then
          details = text_to_job_details(table.concat(section_content, "\n"))
        elseif node_type == "Component" then
          details = text_to_component_details(table.concat(section_content, "\n"))
        elseif node_type == "Area" then
          details = text_to_area_details(table.concat(section_content, "\n"))
        else
          details = table.concat(section_content, "\n")
        end
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
    if node_type == "Job" then
      details = text_to_job_details(table.concat(section_content, "\n"))
    elseif node_type == "Component" then
      details = text_to_component_details(table.concat(section_content, "\n"))
    elseif node_type == "Area" then
      details = text_to_area_details(table.concat(section_content, "\n"))
    else
      details = table.concat(section_content, "\n")
    end
  elseif current_section == "estimation" then
    if node_type == "Job" then
      estimation = text_to_estimation(table.concat(section_content, "\n"))
    end
  elseif current_section == "notes" then
    notes = table.concat(section_content, "\n")
  end

  -- Trim trailing whitespace from multi-line content (only for string details)
  if type(details) == "string" then
    details = vim.trim(details)
  end
  notes = vim.trim(notes)

  return models.Task.new(id, name, details, estimation, tags, notes)
end

return M
