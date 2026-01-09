-- Task text format conversion
local models = require('samplanner.domain.models')
local parsing = require('samplanner.utils.parsing')

local M = {}

-- Local aliases for parsing utilities
local checkbox = parsing.checkbox
local get_checked_value = parsing.get_checked_value
local split_lines = parsing.split_lines
local normalize_empty_lines = parsing.normalize_empty_lines
local finalize_section = parsing.finalize_section
local capture_indented_line = parsing.capture_indented_line
local capture_freeform_line = parsing.capture_freeform_line
local format_section = parsing.format_section
local format_plain_section = parsing.format_plain_section

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

  format_plain_section(lines, "Context / Why", jd.context_why)

  -- Completion status
  table.insert(lines, string.format("%s Completed", checkbox(jd.completed)))
  table.insert(lines, "")

  format_section(lines, "Outcome / Definition of Done", jd.outcome_dod)

  -- Scope section (special formatting with subsections)
  table.insert(lines, "Scope")
  table.insert(lines, "  In scope:")
  if jd.scope_in and jd.scope_in ~= "" then
    for _, line in ipairs(split_lines(jd.scope_in)) do
      table.insert(lines, "    " .. line)
    end
  else
    table.insert(lines, "    - ")
  end
  table.insert(lines, "  Out of scope:")
  if jd.scope_out and jd.scope_out ~= "" then
    for _, line in ipairs(split_lines(jd.scope_out)) do
      table.insert(lines, "    " .. line)
    end
  else
    table.insert(lines, "    - ")
  end
  table.insert(lines, "")

  format_section(lines, "Requirements / Constraints", jd.requirements_constraints)
  format_section(lines, "Dependencies", jd.dependencies)
  format_section(lines, "Approach (brief plan)", jd.approach)
  format_section(lines, "Risks", jd.risks)

  -- Last section without trailing newline
  table.insert(lines, "Validation / Test Plan")
  if jd.validation_test_plan and jd.validation_test_plan ~= "" then
    for _, line in ipairs(split_lines(jd.validation_test_plan)) do
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
  local section_lines = {}

  -- Map sections to their field names and indent sizes
  local section_fields = {
    context = { field = "context_why", indent = 0 },
    outcome = { field = "outcome_dod", indent = 2 },
    requirements = { field = "requirements_constraints", indent = 2 },
    dependencies = { field = "dependencies", indent = 2 },
    approach = { field = "approach", indent = 2 },
    risks = { field = "risks", indent = 2 },
    validation = { field = "validation_test_plan", indent = 2 },
  }

  -- Helper to save current section
  local function save_section()
    if not current_section or #section_lines == 0 then return end

    local content = finalize_section(section_lines)
    if current_section == "scope" then
      if current_subsection == "in" then
        jd.scope_in = content
      elseif current_subsection == "out" then
        jd.scope_out = content
      end
    elseif section_fields[current_section] then
      jd[section_fields[current_section].field] = content
    end
  end

  for line in (text .. "\n"):gmatch("([^\r\n]*)\r?\n") do
    -- Check section headers
    if line:match("^Context / Why$") then
      save_section()
      current_section = "context"
      current_subsection = nil
      section_lines = {}
    elseif line:match("^%[.%]%s+Completed$") then
      jd.completed = line:match("^%[x%]") ~= nil or line:match("^%[X%]") ~= nil
    elseif line:match("^Outcome / Definition of Done$") then
      save_section()
      current_section = "outcome"
      current_subsection = nil
      section_lines = {}
    elseif line:match("^Scope$") then
      save_section()
      current_section = "scope"
      current_subsection = nil
      section_lines = {}
    elseif line:match("^Requirements / Constraints$") then
      save_section()
      current_section = "requirements"
      current_subsection = nil
      section_lines = {}
    elseif line:match("^Dependencies$") then
      save_section()
      current_section = "dependencies"
      current_subsection = nil
      section_lines = {}
    elseif line:match("^Approach") then
      save_section()
      current_section = "approach"
      current_subsection = nil
      section_lines = {}
    elseif line:match("^Risks$") then
      save_section()
      current_section = "risks"
      current_subsection = nil
      section_lines = {}
    elseif line:match("^Validation / Test Plan$") then
      save_section()
      current_section = "validation"
      current_subsection = nil
      section_lines = {}

    -- Scope subsections
    elseif current_section == "scope" and line:match("^%s+In scope:") then
      current_subsection = "in"
      section_lines = {}
    elseif current_section == "scope" and line:match("^%s+Out of scope:") then
      save_section()
      current_subsection = "out"
      section_lines = {}

    -- Content capture
    elseif current_section == "context" then
      capture_freeform_line(line, section_lines)
    elseif current_section == "scope" and current_subsection then
      capture_indented_line(line, section_lines, 4)
    elseif current_section then
      capture_indented_line(line, section_lines, 2)
    end
  end

  -- Save final section
  save_section()

  return models.JobDetails.new(jd)
end

-- Convert ComponentDetails to text format
local function component_details_to_text(component_details)
  local lines = {}
  local cd = component_details or models.ComponentDetails.new()

  format_plain_section(lines, "Purpose / What It Is", cd.purpose)
  format_section(lines, "Capabilities / Features", cd.capabilities)
  format_section(lines, "Acceptance Criteria", cd.acceptance_criteria)
  format_section(lines, "Architecture / Design", cd.architecture_design)
  format_section(lines, "Interfaces / Integration Points", cd.interfaces_integration)
  format_section(lines, "Quality Attributes", cd.quality_attributes)
  format_section(lines, "Related Components", cd.related_components)

  -- Other section (plain, no trailing newline)
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
  local section_lines = {}

  -- Map sections to their field names
  local section_fields = {
    purpose = "purpose",
    capabilities = "capabilities",
    acceptance_criteria = "acceptance_criteria",
    architecture = "architecture_design",
    interfaces = "interfaces_integration",
    quality_attributes = "quality_attributes",
    related_components = "related_components",
    other = "other",
  }

  -- Plain sections (no indentation)
  local plain_sections = { purpose = true, other = true }

  local function save_section()
    if not current_section or #section_lines == 0 then return end
    local field = section_fields[current_section]
    if field then
      cd[field] = finalize_section(section_lines)
    end
  end

  for line in (text .. "\n"):gmatch("([^\r\n]*)\r?\n") do
    if line:match("^Purpose / What It Is$") then
      save_section()
      current_section = "purpose"
      section_lines = {}
    elseif line:match("^Capabilities / Features$") then
      save_section()
      current_section = "capabilities"
      section_lines = {}
    elseif line:match("^Acceptance Criteria$") then
      save_section()
      current_section = "acceptance_criteria"
      section_lines = {}
    elseif line:match("^Architecture / Design$") then
      save_section()
      current_section = "architecture"
      section_lines = {}
    elseif line:match("^Interfaces / Integration Points$") then
      save_section()
      current_section = "interfaces"
      section_lines = {}
    elseif line:match("^Quality Attributes$") then
      save_section()
      current_section = "quality_attributes"
      section_lines = {}
    elseif line:match("^Related Components$") then
      save_section()
      current_section = "related_components"
      section_lines = {}
    elseif line:match("^Other$") then
      save_section()
      current_section = "other"
      section_lines = {}
    elseif current_section then
      if plain_sections[current_section] then
        capture_freeform_line(line, section_lines)
      else
        capture_indented_line(line, section_lines, 2)
      end
    end
  end

  save_section()
  return models.ComponentDetails.new(cd)
end

-- Convert AreaDetails to text format
local function area_details_to_text(area_details)
  local lines = {}
  local ad = area_details or models.AreaDetails.new()

  format_plain_section(lines, "Vision / Purpose", ad.vision_purpose)
  format_section(lines, "Goals / Objectives", ad.goals_objectives)
  format_section(lines, "Scope / Boundaries", ad.scope_boundaries)
  format_section(lines, "Key Components", ad.key_components)
  format_section(lines, "Success Metrics / KPIs", ad.success_metrics)
  format_section(lines, "Stakeholders", ad.stakeholders)
  format_section(lines, "Dependencies / Constraints", ad.dependencies_constraints)

  -- Strategic Context section (plain, no trailing newline)
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
  local section_lines = {}

  -- Map sections to their field names
  local section_fields = {
    vision = "vision_purpose",
    goals = "goals_objectives",
    scope = "scope_boundaries",
    components = "key_components",
    metrics = "success_metrics",
    stakeholders = "stakeholders",
    dependencies = "dependencies_constraints",
    context = "strategic_context",
  }

  -- Plain sections (no indentation)
  local plain_sections = { vision = true, context = true }

  local function save_section()
    if not current_section or #section_lines == 0 then return end
    local field = section_fields[current_section]
    if field then
      ad[field] = finalize_section(section_lines)
    end
  end

  for line in (text .. "\n"):gmatch("([^\r\n]*)\r?\n") do
    if line:match("^Vision / Purpose$") then
      save_section()
      current_section = "vision"
      section_lines = {}
    elseif line:match("^Goals / Objectives$") then
      save_section()
      current_section = "goals"
      section_lines = {}
    elseif line:match("^Scope / Boundaries$") then
      save_section()
      current_section = "scope"
      section_lines = {}
    elseif line:match("^Key Components$") then
      save_section()
      current_section = "components"
      section_lines = {}
    elseif line:match("^Success Metrics / KPIs$") then
      save_section()
      current_section = "metrics"
      section_lines = {}
    elseif line:match("^Stakeholders$") then
      save_section()
      current_section = "stakeholders"
      section_lines = {}
    elseif line:match("^Dependencies / Constraints$") then
      save_section()
      current_section = "dependencies"
      section_lines = {}
    elseif line:match("^Strategic Context$") then
      save_section()
      current_section = "context"
      section_lines = {}
    elseif current_section then
      if plain_sections[current_section] then
        capture_freeform_line(line, section_lines)
      else
        capture_indented_line(line, section_lines, 2)
      end
    end
  end

  save_section()
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
