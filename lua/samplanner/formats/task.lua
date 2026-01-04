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

  -- Add newline to ensure last line is captured, then match lines
  for line in (text .. "\n"):gmatch("([^\r\n]*)\r?\n") do
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
  if #jd.outcome_dod > 0 then
    for _, item in ipairs(jd.outcome_dod) do
      table.insert(lines, "  - " .. item)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Scope section
  table.insert(lines, "Scope")
  table.insert(lines, "  In scope:")
  if #jd.scope_in > 0 then
    for _, item in ipairs(jd.scope_in) do
      table.insert(lines, "    - " .. item)
    end
  else
    table.insert(lines, "    - ")
  end
  table.insert(lines, "  Out of scope:")
  if #jd.scope_out > 0 then
    for _, item in ipairs(jd.scope_out) do
      table.insert(lines, "    - " .. item)
    end
  else
    table.insert(lines, "    - ")
  end
  table.insert(lines, "")

  -- Requirements / Constraints section
  table.insert(lines, "Requirements / Constraints")
  if #jd.requirements_constraints > 0 then
    for _, item in ipairs(jd.requirements_constraints) do
      table.insert(lines, "  - " .. item)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Dependencies section
  table.insert(lines, "Dependencies")
  if #jd.dependencies > 0 then
    for _, item in ipairs(jd.dependencies) do
      table.insert(lines, "  - " .. item)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Approach section
  table.insert(lines, "Approach (brief plan)")
  if #jd.approach > 0 then
    for _, item in ipairs(jd.approach) do
      table.insert(lines, "  - " .. item)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Risks section
  table.insert(lines, "Risks")
  if #jd.risks > 0 then
    for _, item in ipairs(jd.risks) do
      table.insert(lines, "  - " .. item)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Validation / Test Plan section
  table.insert(lines, "Validation / Test Plan")
  if #jd.validation_test_plan > 0 then
    for _, item in ipairs(jd.validation_test_plan) do
      table.insert(lines, "  - " .. item)
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
    outcome_dod = {},
    scope_in = {},
    scope_out = {},
    requirements_constraints = {},
    dependencies = {},
    approach = {},
    risks = {},
    validation_test_plan = {},
    completed = false,
  }

  local current_section = nil
  local current_subsection = nil
  local context_lines = {}

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
    elseif line:match("^Scope$") then
      current_section = "scope"
      current_subsection = nil
    elseif line:match("^Requirements / Constraints$") then
      current_section = "requirements"
      current_subsection = nil
    elseif line:match("^Dependencies$") then
      current_section = "dependencies"
      current_subsection = nil
    elseif line:match("^Approach") then
      current_section = "approach"
      current_subsection = nil
    elseif line:match("^Risks$") then
      current_section = "risks"
      current_subsection = nil
    elseif line:match("^Validation / Test Plan$") then
      current_section = "validation"
      current_subsection = nil

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

    -- Outcome section content
    elseif current_section == "outcome" and line:match("^%s+%-%s*(.*)$") then
      local item = vim.trim(line:match("^%s+%-%s*(.*)$"))
      if item ~= "" then
        table.insert(jd.outcome_dod, item)
      end

    -- Scope section content
    elseif current_section == "scope" and line:match("^%s+In scope:") then
      current_subsection = "in"
    elseif current_section == "scope" and line:match("^%s+Out of scope:") then
      current_subsection = "out"
    elseif current_section == "scope" and current_subsection and line:match("^%s+%s+%-%s*(.*)$") then
      local item = vim.trim(line:match("^%s+%s+%-%s*(.*)$"))
      if item ~= "" then
        if current_subsection == "in" then
          table.insert(jd.scope_in, item)
        elseif current_subsection == "out" then
          table.insert(jd.scope_out, item)
        end
      end

    -- Requirements section content
    elseif current_section == "requirements" and line:match("^%s+%-%s*(.*)$") then
      local item = vim.trim(line:match("^%s+%-%s*(.*)$"))
      if item ~= "" then
        table.insert(jd.requirements_constraints, item)
      end

    -- Dependencies section content
    elseif current_section == "dependencies" and line:match("^%s+%-%s*(.*)$") then
      local item = vim.trim(line:match("^%s+%-%s*(.*)$"))
      if item ~= "" then
        table.insert(jd.dependencies, item)
      end

    -- Approach section content
    elseif current_section == "approach" and line:match("^%s+%-%s*(.*)$") then
      local item = vim.trim(line:match("^%s+%-%s*(.*)$"))
      if item ~= "" then
        table.insert(jd.approach, item)
      end

    -- Risks section content
    elseif current_section == "risks" and line:match("^%s+%-%s*(.*)$") then
      local item = vim.trim(line:match("^%s+%-%s*(.*)$"))
      if item ~= "" then
        table.insert(jd.risks, item)
      end

    -- Validation section content
    elseif current_section == "validation" and line:match("^%s+%-%s*(.*)$") then
      local item = vim.trim(line:match("^%s+%-%s*(.*)$"))
      if item ~= "" then
        table.insert(jd.validation_test_plan, item)
      end
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
  if #cd.capabilities > 0 then
    for _, item in ipairs(cd.capabilities) do
      table.insert(lines, "  - " .. item)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Acceptance Criteria section
  table.insert(lines, "Acceptance Criteria")
  if #cd.acceptance_criteria > 0 then
    for _, item in ipairs(cd.acceptance_criteria) do
      table.insert(lines, "  - " .. item)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Architecture / Design section
  table.insert(lines, "Architecture / Design")
  if #cd.architecture_design > 0 then
    for _, item in ipairs(cd.architecture_design) do
      table.insert(lines, "  - " .. item)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Interfaces / Integration Points section
  table.insert(lines, "Interfaces / Integration Points")
  if #cd.interfaces_integration > 0 then
    for _, item in ipairs(cd.interfaces_integration) do
      table.insert(lines, "  - " .. item)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Quality Attributes section
  table.insert(lines, "Quality Attributes")
  if #cd.quality_attributes > 0 then
    for _, item in ipairs(cd.quality_attributes) do
      table.insert(lines, "  - " .. item)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Related Components section
  table.insert(lines, "Related Components")
  if #cd.related_components > 0 then
    for _, item in ipairs(cd.related_components) do
      table.insert(lines, "  - " .. item)
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
    capabilities = {},
    acceptance_criteria = {},
    architecture_design = {},
    interfaces_integration = {},
    quality_attributes = {},
    related_components = {},
    other = "",
  }

  local current_section = nil
  local purpose_lines = {}
  local other_lines = {}

  -- Add newline to ensure last line is captured, then match lines
  for line in (text .. "\n"):gmatch("([^\r\n]*)\r?\n") do
    -- Check section headers
    if line:match("^Purpose / What It Is$") then
      current_section = "purpose"
      purpose_lines = {}
    elseif line:match("^Capabilities / Features$") then
      -- Save purpose before switching
      if current_section == "purpose" and #purpose_lines > 0 then
        -- Normalize consecutive empty lines
        purpose_lines = normalize_empty_lines(purpose_lines)
        -- Remove trailing empty lines
        while #purpose_lines > 0 and purpose_lines[#purpose_lines] == "" do
          table.remove(purpose_lines)
        end
        -- Remove leading empty lines
        while #purpose_lines > 0 and purpose_lines[1] == "" do
          table.remove(purpose_lines, 1)
        end
        cd.purpose = table.concat(purpose_lines, "\n")
      end
      current_section = "capabilities"
    elseif line:match("^Acceptance Criteria$") then
      current_section = "acceptance_criteria"
    elseif line:match("^Architecture / Design$") then
      current_section = "architecture"
    elseif line:match("^Interfaces / Integration Points$") then
      current_section = "interfaces"
    elseif line:match("^Quality Attributes$") then
      current_section = "quality_attributes"
    elseif line:match("^Related Components$") then
      current_section = "related_components"
    elseif line:match("^Other$") then
      -- Save other before switching
      if current_section == "other" and #other_lines > 0 then
        while #other_lines > 0 and other_lines[#other_lines] == "" do
          table.remove(other_lines)
        end
        cd.other = table.concat(other_lines, "\n")
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

    -- Capabilities section content
    elseif current_section == "capabilities" and line:match("^%s+%-%s*(.*)$") then
      local item = vim.trim(line:match("^%s+%-%s*(.*)$"))
      if item ~= "" then
        table.insert(cd.capabilities, item)
      end

    -- Acceptance Criteria section content
    elseif current_section == "acceptance_criteria" and line:match("^%s+%-%s*(.*)$") then
      local item = vim.trim(line:match("^%s+%-%s*(.*)$"))
      if item ~= "" then
        table.insert(cd.acceptance_criteria, item)
      end

    -- Architecture section content
    elseif current_section == "architecture" and line:match("^%s+%-%s*(.*)$") then
      local item = vim.trim(line:match("^%s+%-%s*(.*)$"))
      if item ~= "" then
        table.insert(cd.architecture_design, item)
      end

    -- Interfaces section content
    elseif current_section == "interfaces" and line:match("^%s+%-%s*(.*)$") then
      local item = vim.trim(line:match("^%s+%-%s*(.*)$"))
      if item ~= "" then
        table.insert(cd.interfaces_integration, item)
      end

    -- Quality Attributes section content
    elseif current_section == "quality_attributes" and line:match("^%s+%-%s*(.*)$") then
      local item = vim.trim(line:match("^%s+%-%s*(.*)$"))
      if item ~= "" then
        table.insert(cd.quality_attributes, item)
      end

    -- Related Components section content
    elseif current_section == "related_components" and line:match("^%s+%-%s*(.*)$") then
      local item = vim.trim(line:match("^%s+%-%s*(.*)$"))
      if item ~= "" then
        table.insert(cd.related_components, item)
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
    -- Normalize consecutive empty lines
    purpose_lines = normalize_empty_lines(purpose_lines)
    -- Remove trailing empty lines
    while #purpose_lines > 0 and purpose_lines[#purpose_lines] == "" do
      table.remove(purpose_lines)
    end
    -- Remove leading empty lines
    while #purpose_lines > 0 and purpose_lines[1] == "" do
      table.remove(purpose_lines, 1)
    end
    cd.purpose = vim.trim(table.concat(purpose_lines, "\n"))
  end

  if current_section == "other" and #other_lines > 0 then
    -- Normalize consecutive empty lines
    other_lines = normalize_empty_lines(other_lines)
    -- Remove trailing empty lines
    while #other_lines > 0 and other_lines[#other_lines] == "" do
      table.remove(other_lines)
    end
    -- Remove leading empty lines
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
  if #ad.goals_objectives > 0 then
    for _, item in ipairs(ad.goals_objectives) do
      table.insert(lines, "  - " .. item)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Scope / Boundaries section
  table.insert(lines, "Scope / Boundaries")
  if #ad.scope_boundaries > 0 then
    for _, item in ipairs(ad.scope_boundaries) do
      table.insert(lines, "  - " .. item)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Key Components section
  table.insert(lines, "Key Components")
  if #ad.key_components > 0 then
    for _, item in ipairs(ad.key_components) do
      table.insert(lines, "  - " .. item)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Success Metrics / KPIs section
  table.insert(lines, "Success Metrics / KPIs")
  if #ad.success_metrics > 0 then
    for _, item in ipairs(ad.success_metrics) do
      table.insert(lines, "  - " .. item)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Stakeholders section
  table.insert(lines, "Stakeholders")
  if #ad.stakeholders > 0 then
    for _, item in ipairs(ad.stakeholders) do
      table.insert(lines, "  - " .. item)
    end
  else
    table.insert(lines, "  - ")
  end
  table.insert(lines, "")

  -- Dependencies / Constraints section
  table.insert(lines, "Dependencies / Constraints")
  if #ad.dependencies_constraints > 0 then
    for _, item in ipairs(ad.dependencies_constraints) do
      table.insert(lines, "  - " .. item)
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
    goals_objectives = {},
    scope_boundaries = {},
    key_components = {},
    success_metrics = {},
    stakeholders = {},
    dependencies_constraints = {},
    strategic_context = "",
  }

  local current_section = nil
  local vision_lines = {}
  local context_lines = {}

  -- Add newline to ensure last line is captured, then match lines
  for line in (text .. "\n"):gmatch("([^\r\n]*)\r?\n") do
    -- Check section headers
    if line:match("^Vision / Purpose$") then
      current_section = "vision"
      vision_lines = {}
    elseif line:match("^Goals / Objectives$") then
      -- Save vision before switching
      if current_section == "vision" and #vision_lines > 0 then
        -- Normalize consecutive empty lines
        vision_lines = normalize_empty_lines(vision_lines)
        -- Remove trailing empty lines
        while #vision_lines > 0 and vision_lines[#vision_lines] == "" do
          table.remove(vision_lines)
        end
        -- Remove leading empty lines
        while #vision_lines > 0 and vision_lines[1] == "" do
          table.remove(vision_lines, 1)
        end
        ad.vision_purpose = table.concat(vision_lines, "\n")
      end
      current_section = "goals"
    elseif line:match("^Scope / Boundaries$") then
      current_section = "scope"
    elseif line:match("^Key Components$") then
      current_section = "components"
    elseif line:match("^Success Metrics / KPIs$") then
      current_section = "metrics"
    elseif line:match("^Stakeholders$") then
      current_section = "stakeholders"
    elseif line:match("^Dependencies / Constraints$") then
      current_section = "dependencies"
    elseif line:match("^Strategic Context$") then
      current_section = "context"
      context_lines = {}

    -- Vision section content (capture everything until next section)
    elseif current_section == "vision" then
      -- Skip leading empty lines, but preserve internal ones
      if line ~= "" then
        table.insert(vision_lines, line)
      elseif #vision_lines > 0 then
        table.insert(vision_lines, "")
      end

    -- Goals section content
    elseif current_section == "goals" and line:match("^%s+%-%s*(.*)$") then
      local item = vim.trim(line:match("^%s+%-%s*(.*)$"))
      if item ~= "" then
        table.insert(ad.goals_objectives, item)
      end

    -- Scope section content
    elseif current_section == "scope" and line:match("^%s+%-%s*(.*)$") then
      local item = vim.trim(line:match("^%s+%-%s*(.*)$"))
      if item ~= "" then
        table.insert(ad.scope_boundaries, item)
      end

    -- Key Components section content
    elseif current_section == "components" and line:match("^%s+%-%s*(.*)$") then
      local item = vim.trim(line:match("^%s+%-%s*(.*)$"))
      if item ~= "" then
        table.insert(ad.key_components, item)
      end

    -- Success Metrics section content
    elseif current_section == "metrics" and line:match("^%s+%-%s*(.*)$") then
      local item = vim.trim(line:match("^%s+%-%s*(.*)$"))
      if item ~= "" then
        table.insert(ad.success_metrics, item)
      end

    -- Stakeholders section content
    elseif current_section == "stakeholders" and line:match("^%s+%-%s*(.*)$") then
      local item = vim.trim(line:match("^%s+%-%s*(.*)$"))
      if item ~= "" then
        table.insert(ad.stakeholders, item)
      end

    -- Dependencies section content
    elseif current_section == "dependencies" and line:match("^%s+%-%s*(.*)$") then
      local item = vim.trim(line:match("^%s+%-%s*(.*)$"))
      if item ~= "" then
        table.insert(ad.dependencies_constraints, item)
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
    -- Normalize consecutive empty lines
    vision_lines = normalize_empty_lines(vision_lines)
    -- Remove trailing empty lines
    while #vision_lines > 0 and vision_lines[#vision_lines] == "" do
      table.remove(vision_lines)
    end
    -- Remove leading empty lines
    while #vision_lines > 0 and vision_lines[1] == "" do
      table.remove(vision_lines, 1)
    end
    ad.vision_purpose = vim.trim(table.concat(vision_lines, "\n"))
  end

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
