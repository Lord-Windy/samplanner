-- Task text format conversion (Markdown format)
local models = require('samplanner.domain.models')
local parsing = require('samplanner.utils.parsing')

local M = {}

-- Local aliases for parsing utilities
local split_lines = parsing.split_lines
local normalize_empty_lines = parsing.normalize_empty_lines
local finalize_section = parsing.finalize_section
local capture_freeform_line = parsing.capture_freeform_line
local format_md_subsection = parsing.format_md_subsection
local format_gfm_checkbox = parsing.format_gfm_checkbox
local format_gfm_checkbox_group = parsing.format_gfm_checkbox_group
local is_h2_header = parsing.is_h2_header
local is_h3_header = parsing.is_h3_header
local parse_gfm_checkbox_value = parsing.parse_gfm_checkbox_value
local normalize_header_to_key = parsing.normalize_header_to_key
local key_to_header = parsing.key_to_header

-- Work type options for checkboxes
local WORK_TYPE_OPTIONS = {
  { label = "New work", value = "new_work", pattern = "New work" },
  { label = "Change", value = "change", pattern = "Change" },
  { label = "Bugfix", value = "bugfix", pattern = "Bugfix" },
  { label = "Research/Spike", value = "research", pattern = "Research/Spike" },
}

-- Estimation method options
local METHOD_OPTIONS = {
  { label = "Similar work", value = "similar_work", pattern = "Similar work" },
  { label = "3-point", value = "three_point", pattern = "3%-point" },
  { label = "Gut feel", value = "gut_feel", pattern = "Gut feel" },
}

-- Confidence options
local CONFIDENCE_OPTIONS = {
  { label = "Low", value = "low", pattern = "Low" },
  { label = "Med", value = "med", pattern = "Med" },
  { label = "High", value = "high", pattern = "High" },
}

-- Convert Estimation to Markdown format
local function estimation_to_text(estimation)
  local lines = {}
  local est = estimation or models.Estimation.new()

  -- Type section
  table.insert(lines, "### Type")
  table.insert(lines, format_gfm_checkbox_group(WORK_TYPE_OPTIONS, est.work_type))
  table.insert(lines, "")

  -- Assumptions section
  table.insert(lines, "### Assumptions")
  if est.assumptions and est.assumptions ~= "" then
    for line in est.assumptions:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
  end
  table.insert(lines, "")

  -- Effort section
  table.insert(lines, "### Effort (hours)")
  table.insert(lines, "**Method:**")
  table.insert(lines, format_gfm_checkbox_group(METHOD_OPTIONS, est.effort.method))
  table.insert(lines, "")
  table.insert(lines, "**Estimate:**")
  table.insert(lines, string.format("- Base effort: %s",
    est.effort.base_hours > 0 and tostring(est.effort.base_hours) .. "h" or ""))
  table.insert(lines, string.format("- Buffer: %s (reason: %s)",
    est.effort.buffer_percent > 0 and tostring(est.effort.buffer_percent) .. "%" or "",
    est.effort.buffer_reason))
  table.insert(lines, string.format("- Total: %s",
    est.effort.total_hours > 0 and tostring(est.effort.total_hours) .. "h" or ""))
  table.insert(lines, "")

  -- Confidence section
  table.insert(lines, "### Confidence")
  table.insert(lines, format_gfm_checkbox_group(CONFIDENCE_OPTIONS, est.confidence))
  table.insert(lines, "")

  -- Schedule section
  table.insert(lines, "### Schedule")
  table.insert(lines, "- Start: " .. est.schedule.start_date)
  table.insert(lines, "- Target finish: " .. est.schedule.target_finish)
  table.insert(lines, "- Milestones:")
  if #est.schedule.milestones > 0 then
    for _, milestone in ipairs(est.schedule.milestones) do
      table.insert(lines, string.format("  - %s — %s", milestone.name or "", milestone.date or ""))
    end
  end
  table.insert(lines, "")

  -- Post-estimate notes section
  table.insert(lines, "### Post-estimate notes")
  table.insert(lines, "**What could make this smaller?**")
  if est.post_estimate_notes.could_be_smaller and est.post_estimate_notes.could_be_smaller ~= "" then
    for line in est.post_estimate_notes.could_be_smaller:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
  end
  table.insert(lines, "")
  table.insert(lines, "**What could make this bigger?**")
  if est.post_estimate_notes.could_be_bigger and est.post_estimate_notes.could_be_bigger ~= "" then
    for line in est.post_estimate_notes.could_be_bigger:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
  end
  table.insert(lines, "")
  table.insert(lines, "**What did I ignore / forget last time?**")
  if est.post_estimate_notes.ignored_last_time and est.post_estimate_notes.ignored_last_time ~= "" then
    for line in est.post_estimate_notes.ignored_last_time:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
  end

  return table.concat(lines, "\n")
end

-- Parse estimation from Markdown text
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
  local section_lines = {}

  local function save_subsection()
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
    elseif current_section == "assumptions" and #section_lines > 0 then
      section_lines = normalize_empty_lines(section_lines)
      while #section_lines > 0 and section_lines[#section_lines] == "" do
        table.remove(section_lines)
      end
      while #section_lines > 0 and section_lines[1] == "" do
        table.remove(section_lines, 1)
      end
      est.assumptions = table.concat(section_lines, "\n")
    end
  end

  for line in (text .. "\n"):gmatch("([^\r\n]*)\r?\n") do
    local is_h3, h3_title = is_h3_header(line)

    if is_h3 then
      save_subsection()
      section_lines = {}

      if h3_title == "Type" then
        current_section = "type"
        current_subsection = nil
      elseif h3_title == "Assumptions" then
        current_section = "assumptions"
        current_subsection = nil
      elseif h3_title:match("^Effort") then
        current_section = "effort"
        current_subsection = nil
      elseif h3_title == "Confidence" then
        current_section = "confidence"
        current_subsection = nil
      elseif h3_title == "Schedule" then
        current_section = "schedule"
        current_subsection = nil
      elseif h3_title:match("^Post%-estimate") then
        current_section = "post_estimate"
        current_subsection = nil
      end

    -- Type section - GFM checkboxes
    elseif current_section == "type" and line:match("^%- %[") then
      local value = parse_gfm_checkbox_value(line, WORK_TYPE_OPTIONS)
      if value then est.work_type = value end

    -- Assumptions section - capture all content
    elseif current_section == "assumptions" then
      if line ~= "" then
        table.insert(section_lines, line)
      elseif #section_lines > 0 then
        table.insert(section_lines, "")
      end

    -- Effort section
    elseif current_section == "effort" then
      if line:match("^%*%*Method:") then
        current_subsection = "method"
      elseif current_subsection == "method" and line:match("^%- %[") then
        local value = parse_gfm_checkbox_value(line, METHOD_OPTIONS)
        if value then est.effort.method = value end
      elseif line:match("^%*%*Estimate:") then
        current_subsection = "estimate"
      elseif current_subsection == "estimate" then
        local base = line:match("Base effort:%s*(%d+)")
        if base then est.effort.base_hours = tonumber(base) or 0 end

        local buffer, reason = line:match("Buffer:%s*(%d+)%%%s*%(reason:%s*(.-)%)")
        if buffer then
          est.effort.buffer_percent = tonumber(buffer) or 0
          est.effort.buffer_reason = vim.trim(reason or "")
        end

        local total = line:match("Total:%s*(%d+)")
        if total then est.effort.total_hours = tonumber(total) or 0 end
      end

    -- Confidence section - GFM checkboxes
    elseif current_section == "confidence" and line:match("^%- %[") then
      local value = parse_gfm_checkbox_value(line, CONFIDENCE_OPTIONS)
      if value then est.confidence = value end

    -- Schedule section
    elseif current_section == "schedule" then
      local start_val = line:match("^%- Start:%s*(.*)$")
      if start_val then est.schedule.start_date = vim.trim(start_val) end

      local finish_val = line:match("^%- Target finish:%s*(.*)$")
      if finish_val then est.schedule.target_finish = vim.trim(finish_val) end

      local milestone_text = line:match("^%s+%-%s+(.*)$")
      if milestone_text and milestone_text ~= "" then
        local name, date = milestone_text:match("(.-)%s*—%s*(.*)")
        if name then
          table.insert(est.schedule.milestones, { name = vim.trim(name), date = vim.trim(date or "") })
        else
          table.insert(est.schedule.milestones, { name = milestone_text, date = "" })
        end
      end

    -- Post-estimate notes section
    elseif current_section == "post_estimate" then
      if line:match("^%*%*What could make this smaller") then
        save_subsection()
        current_subsection = "smaller"
        section_lines = {}
      elseif line:match("^%*%*What could make this bigger") then
        save_subsection()
        current_subsection = "bigger"
        section_lines = {}
      elseif line:match("^%*%*What did I ignore") then
        save_subsection()
        current_subsection = "ignored"
        section_lines = {}
      elseif current_subsection and not line:match("^%*%*") then
        if line ~= "" then
          table.insert(section_lines, line)
        elseif #section_lines > 0 then
          table.insert(section_lines, "")
        end
      end
    end
  end

  -- Save final subsection
  save_subsection()

  return models.Estimation.new(est)
end

-- Convert JobDetails to Markdown format
local function job_details_to_text(job_details)
  local lines = {}
  local jd = job_details or models.JobDetails.new()

  format_md_subsection(lines, "Context / Why", jd.context_why)

  -- Completion status as GFM checkbox
  table.insert(lines, format_gfm_checkbox(jd.completed, "Completed"))
  table.insert(lines, "")

  format_md_subsection(lines, "Outcome / Definition of Done", jd.outcome_dod)

  -- Scope section with bold sub-headers
  table.insert(lines, "### Scope")
  table.insert(lines, "**In scope:**")
  if jd.scope_in and jd.scope_in ~= "" then
    for _, line in ipairs(split_lines(jd.scope_in)) do
      table.insert(lines, line)
    end
  end
  table.insert(lines, "")
  table.insert(lines, "**Out of scope:**")
  if jd.scope_out and jd.scope_out ~= "" then
    for _, line in ipairs(split_lines(jd.scope_out)) do
      table.insert(lines, line)
    end
  end
  table.insert(lines, "")

  format_md_subsection(lines, "Requirements / Constraints", jd.requirements_constraints)
  format_md_subsection(lines, "Dependencies", jd.dependencies)
  format_md_subsection(lines, "Approach (brief plan)", jd.approach)
  format_md_subsection(lines, "Risks", jd.risks)
  format_md_subsection(lines, "Validation / Test Plan", jd.validation_test_plan)

  -- Custom H3 sections
  if jd.custom and next(jd.custom) then
    for key, value in pairs(jd.custom) do
      if value and value ~= "" then
        table.insert(lines, "### " .. key_to_header(key))
        table.insert(lines, "")
        table.insert(lines, value)
        table.insert(lines, "")
      end
    end
  end

  return table.concat(lines, "\n")
end

-- Parse JobDetails from Markdown text
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
    custom = {},
  }

  local current_section = nil
  local current_subsection = nil
  local current_custom_key = nil
  local section_lines = {}
  local custom_section_lines = {}

  local function save_custom_section()
    if current_custom_key and #custom_section_lines > 0 then
      local content = finalize_section(custom_section_lines)
      if content ~= "" then
        jd.custom[current_custom_key] = content
      end
      current_custom_key = nil
      custom_section_lines = {}
    end
  end

  local function save_section()
    if not current_section or #section_lines == 0 then return end

    local content = finalize_section(section_lines)
    if current_section == "scope" then
      if current_subsection == "in" then
        jd.scope_in = content
      elseif current_subsection == "out" then
        jd.scope_out = content
      end
    elseif current_section == "context" then
      jd.context_why = content
    elseif current_section == "outcome" then
      jd.outcome_dod = content
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

  for line in (text .. "\n"):gmatch("([^\r\n]*)\r?\n") do
    local is_h3, h3_title = is_h3_header(line)

    if is_h3 then
      save_section()
      save_custom_section()
      section_lines = {}
      current_subsection = nil

      if h3_title == "Context / Why" then
        current_section = "context"
      elseif h3_title == "Outcome / Definition of Done" then
        current_section = "outcome"
      elseif h3_title == "Scope" then
        current_section = "scope"
      elseif h3_title == "Requirements / Constraints" then
        current_section = "requirements"
      elseif h3_title == "Dependencies" then
        current_section = "dependencies"
      elseif h3_title:match("^Approach") then
        current_section = "approach"
      elseif h3_title == "Risks" then
        current_section = "risks"
      elseif h3_title == "Validation / Test Plan" then
        current_section = "validation"
      else
        current_section = "custom"
        current_custom_key = normalize_header_to_key(h3_title)
      end

    -- Completion checkbox
    elseif line:match("^%- %[[xX]%] Completed") then
      jd.completed = true
    elseif line:match("^%- %[ %] Completed") then
      jd.completed = false

    -- Scope subsections
    elseif current_section == "scope" then
      if line:match("^%*%*In scope:") then
        save_section()
        current_subsection = "in"
        section_lines = {}
      elseif line:match("^%*%*Out of scope:") then
        save_section()
        current_subsection = "out"
        section_lines = {}
      elseif current_subsection then
        capture_freeform_line(line, section_lines)
      end

    -- Content capture for other sections
    elseif current_section == "custom" and current_custom_key then
      capture_freeform_line(line, custom_section_lines)
    elseif current_section then
      capture_freeform_line(line, section_lines)
    end
  end

  save_section()
  save_custom_section()

  return models.JobDetails.new(jd)
end

-- Convert ComponentDetails to Markdown format
local function component_details_to_text(component_details)
  local lines = {}
  local cd = component_details or models.ComponentDetails.new()

  format_md_subsection(lines, "Purpose / What It Is", cd.purpose)
  format_md_subsection(lines, "Capabilities / Features", cd.capabilities)
  format_md_subsection(lines, "Acceptance Criteria", cd.acceptance_criteria)
  format_md_subsection(lines, "Architecture / Design", cd.architecture_design)
  format_md_subsection(lines, "Interfaces / Integration Points", cd.interfaces_integration)
  format_md_subsection(lines, "Quality Attributes", cd.quality_attributes)
  format_md_subsection(lines, "Related Components", cd.related_components)
  format_md_subsection(lines, "Other", cd.other)

  -- Custom H3 sections
  if cd.custom and next(cd.custom) then
    for key, value in pairs(cd.custom) do
      if value and value ~= "" then
        table.insert(lines, "### " .. key_to_header(key))
        table.insert(lines, "")
        table.insert(lines, value)
        table.insert(lines, "")
      end
    end
  end

  return table.concat(lines, "\n")
end

-- Parse ComponentDetails from Markdown text
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
    custom = {},
  }

  local current_section = nil
  local current_custom_key = nil
  local section_lines = {}
  local custom_section_lines = {}

  local section_map = {
    ["Purpose / What It Is"] = "purpose",
    ["Capabilities / Features"] = "capabilities",
    ["Acceptance Criteria"] = "acceptance_criteria",
    ["Architecture / Design"] = "architecture_design",
    ["Interfaces / Integration Points"] = "interfaces_integration",
    ["Quality Attributes"] = "quality_attributes",
    ["Related Components"] = "related_components",
    ["Other"] = "other",
  }

  local function save_custom_section()
    if current_custom_key and #custom_section_lines > 0 then
      local content = finalize_section(custom_section_lines)
      if content ~= "" then
        cd.custom[current_custom_key] = content
      end
      current_custom_key = nil
      custom_section_lines = {}
    end
  end

  local function save_section()
    if not current_section or #section_lines == 0 then return end
    cd[current_section] = finalize_section(section_lines)
  end

  for line in (text .. "\n"):gmatch("([^\r\n]*)\r?\n") do
    local is_h3, h3_title = is_h3_header(line)

    if is_h3 then
      save_section()
      save_custom_section()
      section_lines = {}

      if section_map[h3_title] then
        current_section = section_map[h3_title]
      else
        current_section = "custom"
        current_custom_key = normalize_header_to_key(h3_title)
      end
    elseif current_section == "custom" and current_custom_key then
      capture_freeform_line(line, custom_section_lines)
    elseif current_section then
      capture_freeform_line(line, section_lines)
    end
  end

  save_section()
  save_custom_section()
  return models.ComponentDetails.new(cd)
end

-- Convert AreaDetails to Markdown format
local function area_details_to_text(area_details)
  local lines = {}
  local ad = area_details or models.AreaDetails.new()

  format_md_subsection(lines, "Vision / Purpose", ad.vision_purpose)
  format_md_subsection(lines, "Goals / Objectives", ad.goals_objectives)
  format_md_subsection(lines, "Scope / Boundaries", ad.scope_boundaries)
  format_md_subsection(lines, "Key Components", ad.key_components)
  format_md_subsection(lines, "Success Metrics / KPIs", ad.success_metrics)
  format_md_subsection(lines, "Stakeholders", ad.stakeholders)
  format_md_subsection(lines, "Dependencies / Constraints", ad.dependencies_constraints)
  format_md_subsection(lines, "Strategic Context", ad.strategic_context)

  -- Custom H3 sections
  if ad.custom and next(ad.custom) then
    for key, value in pairs(ad.custom) do
      if value and value ~= "" then
        table.insert(lines, "### " .. key_to_header(key))
        table.insert(lines, "")
        table.insert(lines, value)
        table.insert(lines, "")
      end
    end
  end

  return table.concat(lines, "\n")
end

-- Parse AreaDetails from Markdown text
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
    custom = {},
  }

  local current_section = nil
  local current_custom_key = nil
  local section_lines = {}
  local custom_section_lines = {}

  local section_map = {
    ["Vision / Purpose"] = "vision_purpose",
    ["Goals / Objectives"] = "goals_objectives",
    ["Scope / Boundaries"] = "scope_boundaries",
    ["Key Components"] = "key_components",
    ["Success Metrics / KPIs"] = "success_metrics",
    ["Stakeholders"] = "stakeholders",
    ["Dependencies / Constraints"] = "dependencies_constraints",
    ["Strategic Context"] = "strategic_context",
  }

  local function save_custom_section()
    if current_custom_key and #custom_section_lines > 0 then
      local content = finalize_section(custom_section_lines)
      if content ~= "" then
        ad.custom[current_custom_key] = content
      end
      current_custom_key = nil
      custom_section_lines = {}
    end
  end

  local function save_section()
    if not current_section or #section_lines == 0 then return end
    ad[current_section] = finalize_section(section_lines)
  end

  for line in (text .. "\n"):gmatch("([^\r\n]*)\r?\n") do
    local is_h3, h3_title = is_h3_header(line)

    if is_h3 then
      save_section()
      save_custom_section()
      section_lines = {}

      if section_map[h3_title] then
        current_section = section_map[h3_title]
      else
        current_section = "custom"
        current_custom_key = normalize_header_to_key(h3_title)
      end
    elseif current_section == "custom" and current_custom_key then
      capture_freeform_line(line, custom_section_lines)
    elseif current_section then
      capture_freeform_line(line, section_lines)
    end
  end

  save_section()
  save_custom_section()
  return models.AreaDetails.new(ad)
end

-- Convert Task to editable Markdown format
-- @param task: Task - The task to convert
-- @param node_type: string|nil - "Area", "Component", or "Job" (nil shows no estimation)
-- @return string - Markdown format
function M.task_to_text(task, node_type)
  local lines = {}

  -- Task header with H1
  table.insert(lines, "# Task: " .. (task.id or "") .. " - " .. (task.name or ""))
  table.insert(lines, "")

  -- Details section
  table.insert(lines, "## Details")
  table.insert(lines, "")
  if node_type == "Job" then
    if type(task.details) == "table" then
      table.insert(lines, job_details_to_text(task.details))
    elseif task.details and task.details ~= "" then
      table.insert(lines, task.details)
    end
  elseif node_type == "Component" then
    if type(task.details) == "table" then
      table.insert(lines, component_details_to_text(task.details))
    elseif task.details and task.details ~= "" then
      table.insert(lines, task.details)
    end
  elseif node_type == "Area" then
    if type(task.details) == "table" then
      table.insert(lines, area_details_to_text(task.details))
    elseif task.details and task.details ~= "" then
      table.insert(lines, task.details)
    end
  else
    if task.details and task.details ~= "" then
      table.insert(lines, tostring(task.details))
    end
  end

  -- Estimation section (only for Jobs)
  if node_type == "Job" then
    table.insert(lines, "## Estimation")
    table.insert(lines, "")
    table.insert(lines, estimation_to_text(task.estimation))
    table.insert(lines, "")
  end

  -- Notes section
  table.insert(lines, "## Notes")
  if task.notes and task.notes ~= "" then
    table.insert(lines, task.notes)
  end
  table.insert(lines, "")

  -- Tags section
  table.insert(lines, "## Tags")
  if task.tags and #task.tags > 0 then
    table.insert(lines, table.concat(task.tags, ", "))
  end
  table.insert(lines, "")

  -- Custom H2 sections
  if task.custom and next(task.custom) then
    for key, value in pairs(task.custom) do
      if value and value ~= "" then
        table.insert(lines, "## " .. key_to_header(key))
        table.insert(lines, "")
        table.insert(lines, value)
        table.insert(lines, "")
      end
    end
  end

  return table.concat(lines, "\n")
end

-- Parse Markdown text back to Task
-- @param text: string - Markdown format
-- @param node_type: string|nil - "Area", "Component", or "Job"
-- @return Task - Parsed task
function M.text_to_task(text, node_type)
  local id = ""
  local name = ""
  local details = ""
  local estimation = nil
  local notes = ""
  local tags = {}
  local custom = {}
  local current_custom_key = nil
  local custom_section_content = {}

  local current_section = nil
  local section_content = {}

  local function save_custom_section()
    if current_custom_key and #custom_section_content > 0 then
      local content = vim.trim(table.concat(custom_section_content, "\n"))
      if content ~= "" then
        custom[current_custom_key] = content
      end
      current_custom_key = nil
      custom_section_content = {}
    end
  end

  local function save_section()
    if current_section == "details" then
      local content = table.concat(section_content, "\n")
      if node_type == "Job" then
        details = text_to_job_details(content)
      elseif node_type == "Component" then
        details = text_to_component_details(content)
      elseif node_type == "Area" then
        details = text_to_area_details(content)
      else
        details = vim.trim(content)
      end
    elseif current_section == "estimation" then
      if node_type == "Job" then
        estimation = text_to_estimation(table.concat(section_content, "\n"))
      end
    elseif current_section == "notes" then
      notes = vim.trim(table.concat(section_content, "\n"))
    end
  end

  for line in (text .. "\n"):gmatch("([^\r\n]*)\r?\n") do
    -- Check for H1 task header
    local task_id, task_name = parsing.parse_h1_task_header(line)
    if task_id then
      id = task_id
      name = task_name
      current_section = "header"
      section_content = {}

    -- Check for stray H1 headers (other than task header)
    elseif line:match("^# [^#]") then
      local h1_content = vim.trim(line:match("^%s*#%s*(.*)$") or "")
      if notes ~= "" then
        notes = notes .. "\n\n"
      end
      notes = notes .. h1_content

    -- Check for H2 section headers
    else
      local is_h2, h2_title = is_h2_header(line)
      if is_h2 then
        save_section()
        save_custom_section()
        section_content = {}

        if h2_title == "Details" then
          current_section = "details"
        elseif h2_title == "Estimation" then
          current_section = "estimation"
        elseif h2_title == "Notes" then
          current_section = "notes"
        elseif h2_title == "Tags" then
          current_section = "tags"
        else
          current_section = "custom"
          current_custom_key = normalize_header_to_key(h2_title)
        end

      -- Tags parsing (comma-separated on single line)
      elseif current_section == "tags" then
        if line ~= "" then
          for tag in line:gmatch("[^,]+") do
            local trimmed = vim.trim(tag)
            if trimmed ~= "" then
              table.insert(tags, trimmed)
            end
          end
        end

      -- Content capture for other sections
      elseif current_section == "custom" and current_custom_key then
        if line ~= "" or #custom_section_content > 0 then
          table.insert(custom_section_content, line)
        end
      elseif current_section and current_section ~= "header" and current_section ~= "tags" then
        table.insert(section_content, line)
      end
    end
  end

  -- Save final sections
  save_section()
  save_custom_section()

  return models.Task.new(id, name, details, estimation, tags, notes, custom)
end

return M
