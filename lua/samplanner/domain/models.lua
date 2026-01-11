local M = {}

-- Helper to migrate a field from array to string format
-- @param value: any - The value to migrate
-- @param helpers: table - The array_string_helpers module
-- @return string - The migrated value
local function migrate_field(value, helpers)
  if type(value) == "table" then
    return helpers.array_to_text(value)
  end
  return value or ""
end

-- ProjectInfo model
-- JSON: { "id": "ej-1", "name": "Example Json" }
M.ProjectInfo = {}
M.ProjectInfo.__index = M.ProjectInfo

function M.ProjectInfo.new(id, name)
  local self = setmetatable({}, M.ProjectInfo)
  self.id = id or ""
  self.name = name or ""
  return self
end

-- Estimation model (for Jobs only)
-- JSON: {
--   "work_type": "new_work|change|bugfix|research",
--   "assumptions": "- assumption 1\n- assumption 2",
--   "effort": {
--     "method": "similar_work|three_point|gut_feel",
--     "base_hours": 0,
--     "buffer_percent": 0,
--     "buffer_reason": "",
--     "total_hours": 0
--   },
--   "confidence": "low|med|high",
--   "schedule": {
--     "start_date": "",
--     "target_finish": "",
--     "milestones": [{"name": "", "date": ""}]
--   },
--   "post_estimate_notes": {
--     "could_be_smaller": "- item 1\n- item 2",
--     "could_be_bigger": "- item 1\n- item 2",
--     "ignored_last_time": "- item 1\n- item 2"
--   }
-- }
M.Estimation = {}
M.Estimation.__index = M.Estimation

function M.Estimation.new(data)
  data = data or {}
  local self = setmetatable({}, M.Estimation)
  local helpers = require('samplanner.migrations.array_string_helpers')

  self.work_type = data.work_type or ""
  self.assumptions = migrate_field(data.assumptions, helpers)

  self.effort = {
    method = data.effort and data.effort.method or "",
    base_hours = data.effort and data.effort.base_hours or 0,
    buffer_percent = data.effort and data.effort.buffer_percent or 0,
    buffer_reason = data.effort and data.effort.buffer_reason or "",
    total_hours = data.effort and data.effort.total_hours or 0,
  }
  self.confidence = data.confidence or ""
  self.schedule = {
    start_date = data.schedule and data.schedule.start_date or "",
    target_finish = data.schedule and data.schedule.target_finish or "",
    milestones = data.schedule and data.schedule.milestones or {},
  }

  local pen = data.post_estimate_notes or {}
  self.post_estimate_notes = {
    could_be_smaller = migrate_field(pen.could_be_smaller, helpers),
    could_be_bigger = migrate_field(pen.could_be_bigger, helpers),
    ignored_last_time = migrate_field(pen.ignored_last_time, helpers),
  }
  return self
end

-- Check if estimation has any meaningful data
function M.Estimation:is_empty()
  return self.work_type == ""
    and self.assumptions == ""
    and self.effort.method == ""
    and self.effort.base_hours == 0
    and self.confidence == ""
    and self.schedule.start_date == ""
    and self.schedule.target_finish == ""
    and #self.schedule.milestones == 0
    and self.post_estimate_notes.could_be_smaller == ""
    and self.post_estimate_notes.could_be_bigger == ""
    and self.post_estimate_notes.ignored_last_time == ""
end

-- JobDetails model (structured details for Job type tasks)
-- JSON: {
--   "context_why": "",
--   "outcome_dod": "- item 1\n- item 2",
--   "scope_in": "- item 1\n- item 2",
--   "scope_out": "- item 1\n- item 2",
--   "requirements_constraints": "- item 1\n- item 2",
--   "dependencies": "- item 1\n- item 2",
--   "approach": "- item 1\n- item 2",
--   "risks": "- item 1\n- item 2",
--   "validation_test_plan": "- item 1\n- item 2",
--   "completed": false
-- }
M.JobDetails = {}
M.JobDetails.__index = M.JobDetails

function M.JobDetails.new(data)
  data = data or {}
  local self = setmetatable({}, M.JobDetails)
  local helpers = require('samplanner.migrations.array_string_helpers')

  self.context_why = data.context_why or ""
  self.outcome_dod = migrate_field(data.outcome_dod, helpers)
  self.scope_in = migrate_field(data.scope_in, helpers)
  self.scope_out = migrate_field(data.scope_out, helpers)
  self.requirements_constraints = migrate_field(data.requirements_constraints, helpers)
  self.dependencies = migrate_field(data.dependencies, helpers)
  self.approach = migrate_field(data.approach, helpers)
  self.risks = migrate_field(data.risks, helpers)
  self.validation_test_plan = migrate_field(data.validation_test_plan, helpers)
  self.completed = data.completed or false
  self.custom = data.custom or {}
  return self
end

-- Check if job details has any meaningful data
function M.JobDetails:is_empty()
  return self.context_why == ""
    and self.outcome_dod == ""
    and self.scope_in == ""
    and self.scope_out == ""
    and self.requirements_constraints == ""
    and self.dependencies == ""
    and self.approach == ""
    and self.risks == ""
    and self.validation_test_plan == ""
    and not self.completed
end

-- ComponentDetails model (structured details for Component type tasks)
-- JSON: {
--   "purpose": "",
--   "capabilities": "- item 1\n- item 2",
--   "acceptance_criteria": "- item 1\n- item 2",
--   "architecture_design": "- item 1\n- item 2",
--   "interfaces_integration": "- item 1\n- item 2",
--   "quality_attributes": "- item 1\n- item 2",
--   "related_components": "- item 1\n- item 2",
--   "other": ""
-- }
M.ComponentDetails = {}
M.ComponentDetails.__index = M.ComponentDetails

function M.ComponentDetails.new(data)
  data = data or {}
  local self = setmetatable({}, M.ComponentDetails)
  local helpers = require('samplanner.migrations.array_string_helpers')

  self.purpose = data.purpose or ""
  self.capabilities = migrate_field(data.capabilities, helpers)
  self.acceptance_criteria = migrate_field(data.acceptance_criteria, helpers)
  self.architecture_design = migrate_field(data.architecture_design, helpers)
  self.interfaces_integration = migrate_field(data.interfaces_integration, helpers)
  self.quality_attributes = migrate_field(data.quality_attributes, helpers)
  self.related_components = migrate_field(data.related_components, helpers)
  self.other = data.other or ""
  self.custom = data.custom or {}
  return self
end

-- Check if component details has any meaningful data
function M.ComponentDetails:is_empty()
  return self.purpose == ""
    and self.capabilities == ""
    and self.acceptance_criteria == ""
    and self.architecture_design == ""
    and self.interfaces_integration == ""
    and self.quality_attributes == ""
    and self.related_components == ""
    and self.other == ""
end

-- AreaDetails model (structured details for Area type tasks)
-- JSON: {
--   "vision_purpose": "",
--   "goals_objectives": "- item 1\n- item 2",
--   "scope_boundaries": "- item 1\n- item 2",
--   "key_components": "- item 1\n- item 2",
--   "success_metrics": "- item 1\n- item 2",
--   "stakeholders": "- item 1\n- item 2",
--   "dependencies_constraints": "- item 1\n- item 2",
--   "strategic_context": ""
-- }
M.AreaDetails = {}
M.AreaDetails.__index = M.AreaDetails

function M.AreaDetails.new(data)
  data = data or {}
  local self = setmetatable({}, M.AreaDetails)
  local helpers = require('samplanner.migrations.array_string_helpers')

  self.vision_purpose = data.vision_purpose or ""
  self.goals_objectives = migrate_field(data.goals_objectives, helpers)
  self.scope_boundaries = migrate_field(data.scope_boundaries, helpers)
  self.key_components = migrate_field(data.key_components, helpers)
  self.success_metrics = migrate_field(data.success_metrics, helpers)
  self.stakeholders = migrate_field(data.stakeholders, helpers)
  self.dependencies_constraints = migrate_field(data.dependencies_constraints, helpers)
  self.strategic_context = data.strategic_context or ""
  self.custom = data.custom or {}
  return self
end

-- Check if area details has any meaningful data
function M.AreaDetails:is_empty()
  return self.vision_purpose == ""
    and self.goals_objectives == ""
    and self.scope_boundaries == ""
    and self.key_components == ""
    and self.success_metrics == ""
    and self.stakeholders == ""
    and self.dependencies_constraints == ""
    and self.strategic_context == ""
end

-- FreeformDetails model (completely freeform content, no predefined structure)
-- JSON: {
--   "content": "any freeform text here",
--   "custom": { "section_name": "content" }
-- }
M.FreeformDetails = {}
M.FreeformDetails.__index = M.FreeformDetails

function M.FreeformDetails.new(data)
  data = data or {}
  local self = setmetatable({}, M.FreeformDetails)
  self.content = data.content or ""
  self.custom = data.custom or {}
  return self
end

-- Check if freeform details has any meaningful data
function M.FreeformDetails:is_empty()
  return self.content == ""
    and (not self.custom or not next(self.custom))
end

-- Task model
-- JSON: {
--   "name": "name",
--   "details": "description" or {...} (JobDetails for Job type, ComponentDetails for Component type),
--   "estimation": {...} or nil,
--   "notes": "migrated old estimation or other notes",
--   "tags": ["",""]
-- }
M.Task = {}
M.Task.__index = M.Task

function M.Task.new(id, name, details, estimation, tags, notes, custom)
  local self = setmetatable({}, M.Task)
  self.id = id or ""
  self.name = name or ""
  -- details can be AreaDetails (for Area) or JobDetails (for Job) or ComponentDetails (for Component) or FreeformDetails (for Freeform)
  if details and type(details) == "table" and getmetatable(details) == M.JobDetails then
    self.details = details
  elseif details and type(details) == "table" and getmetatable(details) == M.ComponentDetails then
    self.details = details
  elseif details and type(details) == "table" and getmetatable(details) == M.AreaDetails then
    self.details = details
  elseif details and type(details) == "table" and getmetatable(details) == M.FreeformDetails then
    self.details = details
  elseif details and type(details) == "table" then
    -- Try to determine which type of details this should be
    -- Check for JobDetails fields
    local has_job_fields = details.context_why ~= nil or details.outcome_dod ~= nil or details.approach ~= nil
    -- Check for ComponentDetails fields
    local has_component_fields = details.purpose ~= nil or details.capabilities ~= nil or details.acceptance_criteria ~= nil
    -- Check for AreaDetails fields
    local has_area_fields = details.vision_purpose ~= nil or details.goals_objectives ~= nil or details.key_components ~= nil
    -- Check for FreeformDetails fields (content field with no other structured fields)
    local has_freeform_fields = details.content ~= nil and not has_job_fields and not has_component_fields and not has_area_fields

    if has_job_fields then
      self.details = M.JobDetails.new(details)
    elseif has_component_fields then
      self.details = M.ComponentDetails.new(details)
    elseif has_area_fields then
      self.details = M.AreaDetails.new(details)
    elseif has_freeform_fields then
      self.details = M.FreeformDetails.new(details)
    else
      self.details = details or ""
    end
  else
    self.details = details or ""
  end
  -- estimation is now an Estimation object (or nil for non-Jobs)
  if estimation and type(estimation) == "table" and getmetatable(estimation) == M.Estimation then
    self.estimation = estimation
  elseif estimation and type(estimation) == "table" then
    self.estimation = M.Estimation.new(estimation)
  else
    self.estimation = nil
  end
  self.notes = notes or ""
  self.tags = tags or {}
  self.custom = custom or {}
  return self
end

-- StructureNode model (for Area, Component, Job)
-- JSON: {
--   "1": {
--     "type": "Area",
--     "subtasks": {
--       "1.1": {
--         "type": "Component",
--         "subtasks": {
--           "1.1.1": {"type": "Job"}
--         }
--       }
--     }
--   }
-- }
M.StructureNode = {}
M.StructureNode.__index = M.StructureNode

function M.StructureNode.new(id, node_type, subtasks)
  local self = setmetatable({}, M.StructureNode)
  self.id = id or ""
  self.type = node_type or "Job"  -- "Area", "Component", or "Job"
  self.subtasks = subtasks or {}
  return self
end

-- TimeLog model
-- JSON: {
--   "start_timestamp": "iso-timestamp",
--   "end_timestamp": "iso-timestamp",
--   "notes": "",
--   "interruptions": "",
--   "interruption_minutes": 0,
--   "tasks": ["links to task_list"],
--   "session_type": "coding|testing|debugging|planning|design|review|research|meeting|admin",
--   "planned_duration_minutes": 0,
--   "focus_rating": 0,
--   "energy_level": { "start": 0, "end": 0 },
--   "context_switches": 0,
--   "defects": { "found": "- item 1\n- item 2", "fixed": "- item 1\n- item 2" },
--   "deliverables": "- item 1\n- item 2",
--   "blockers": "- item 1\n- item 2",
--   "retrospective": { "what_went_well": "- item 1\n- item 2", "what_needs_improvement": "- item 1\n- item 2", "lessons_learned": "- item 1\n- item 2" }
-- }
M.TimeLog = {}
M.TimeLog.__index = M.TimeLog

function M.TimeLog.new(start_timestamp, end_timestamp, notes, interruptions, interruption_minutes, tasks, session_type, planned_duration_minutes, focus_rating, energy_level, context_switches, defects, deliverables, blockers, retrospective)
  local self = setmetatable({}, M.TimeLog)
  local helpers = require('samplanner.migrations.array_string_helpers')

  self.start_timestamp = start_timestamp or ""
  self.end_timestamp = end_timestamp or ""
  self.notes = notes or ""
  self.interruptions = interruptions or ""
  self.interruption_minutes = interruption_minutes or 0
  self.tasks = tasks or {}  -- array of task IDs - KEEP AS ARRAY
  self.session_type = session_type or ""
  self.planned_duration_minutes = planned_duration_minutes or 0
  self.focus_rating = focus_rating or 0
  self.energy_level = energy_level or { start = 0, ["end"] = 0 }
  self.context_switches = context_switches or 0

  local def = defects or {}
  self.defects = {
    found = migrate_field(def.found, helpers),
    fixed = migrate_field(def.fixed, helpers),
  }

  self.deliverables = migrate_field(deliverables, helpers)
  self.blockers = migrate_field(blockers, helpers)

  local retro = retrospective or {}
  self.retrospective = {
    what_went_well = migrate_field(retro.what_went_well, helpers),
    what_needs_improvement = migrate_field(retro.what_needs_improvement, helpers),
    lessons_learned = migrate_field(retro.lessons_learned, helpers),
  }

  return self
end

-- Project model (root level)
-- JSON: { "project_info": {...}, "structure": {...}, "task_list": {...}, "time_log": [...], "tags": [...], "notes": "" }
M.Project = {}
M.Project.__index = M.Project

function M.Project.new(project_info, structure, task_list, time_log, tags, notes)
  local self = setmetatable({}, M.Project)
  self.project_info = project_info or M.ProjectInfo.new()
  self.structure = structure or {}
  self.task_list = task_list or {}
  self.time_log = time_log or {}
  self.tags = tags or {}
  self.notes = notes or ""
  return self
end

-- Helper function to create a StructureNode from a table
function M.create_structure_from_table(data)
  local result = {}
  for id, node in pairs(data) do
    local subtasks = {}
    if node.subtasks then
      subtasks = M.create_structure_from_table(node.subtasks)
    end
    result[id] = M.StructureNode.new(id, node.type, subtasks)
  end
  return result
end

-- Helper function to get node type by ID from structure
local function get_node_type(structure, task_id)
  local function search(nodes, id)
    for node_id, node in pairs(nodes) do
      if node_id == id then
        return node.type
      end
      if node.subtasks then
        local found = search(node.subtasks, id)
        if found then return found end
      end
    end
    return nil
  end
  return search(structure, task_id)
end

-- Configuration for details types by node type
local details_config = {
  Job = {
    model_fn = function() return M.JobDetails.new() end,
    model_with_data = function(data) return M.JobDetails.new(data) end,
    check_fields = {"context_why", "outcome_dod", "scope_in"},
  },
  Component = {
    model_fn = function() return M.ComponentDetails.new() end,
    model_with_data = function(data) return M.ComponentDetails.new(data) end,
    check_fields = {"purpose", "capabilities", "acceptance_criteria"},
  },
  Area = {
    model_fn = function() return M.AreaDetails.new() end,
    model_with_data = function(data) return M.AreaDetails.new(data) end,
    check_fields = {"vision_purpose", "goals_objectives", "key_components"},
  },
  Freeform = {
    model_fn = function() return M.FreeformDetails.new() end,
    model_with_data = function(data) return M.FreeformDetails.new(data) end,
    check_fields = {"content"},
  },
}

-- Helper to prepend migration note
local function prepend_migration_note(content, notes)
  local prefix = "Migrated details:\n" .. content
  if notes ~= "" then
    return prefix .. "\n\n" .. notes
  end
  return prefix
end

-- Helper function to validate and migrate details based on node type
local function validate_and_migrate_details(task_data, node_type, notes)
  local details = task_data.details
  local config = details_config[node_type] or details_config.Area

  -- If details doesn't exist, create empty details
  if not details then
    return config.model_fn(), notes
  end

  -- If details is a table, check if it conforms to expected structure
  if type(details) == "table" then
    for _, field in ipairs(config.check_fields) do
      if details[field] ~= nil then
        return config.model_with_data(details), notes
      end
    end
    -- Table but not conforming structure - create empty details
    local new_details = config.model_fn()
    -- Preserve custom fields if they exist
    if details.custom and type(details.custom) == "table" then
      new_details.custom = details.custom
    end
    -- Also preserve any other unknown fields that might have custom content
    for k, v in pairs(details) do
      if k ~= "custom" and not new_details[k] then
        new_details[k] = v
      end
    end
    -- Migrate the entire details table to notes for backward compatibility
    notes = prepend_migration_note(vim.inspect(details), notes)
    return new_details, notes
  end

  -- If details is a string (old format), migrate to notes
  if type(details) == "string" and details ~= "" then
    notes = prepend_migration_note(details, notes)
    return config.model_fn(), notes
  end

  -- Default: empty details
  return config.model_fn(), notes
end

-- Helper function to create Project from JSON-like table
function M.Project.from_table(data)
  local project_info = M.ProjectInfo.new(
    data.project_info and data.project_info.id,
    data.project_info and data.project_info.name
  )

  local structure = {}
  if data.structure then
    structure = M.create_structure_from_table(data.structure)
  end

  local task_list = {}
  if data.task_list then
    for id, task_data in pairs(data.task_list) do
      local estimation = nil
      local notes = task_data.notes or ""

      -- Handle estimation migration: if it's a string, move to notes
      if task_data.estimation then
        if type(task_data.estimation) == "string" and task_data.estimation ~= "" then
          -- Old format: string estimation - migrate to notes
          if notes ~= "" then
            notes = task_data.estimation .. "\n\n" .. notes
          else
            notes = task_data.estimation
          end
          estimation = nil
        elseif type(task_data.estimation) == "table" then
          -- New format: structured estimation
          estimation = M.Estimation.new(task_data.estimation)
        end
      end

      -- Get node type and validate/migrate details
      local node_type = get_node_type(data.structure or {}, id)
      local details
      details, notes = validate_and_migrate_details(task_data, node_type, notes)

      task_list[id] = M.Task.new(
        id,
        task_data.name,
        details,
        estimation,
        task_data.tags,
        notes,
        task_data.custom
      )
    end
  end
  
  local time_log = {}
  if data.time_log then
    for i, log_data in ipairs(data.time_log) do
      time_log[i] = M.TimeLog.new(
        log_data.start_timestamp,
        log_data.end_timestamp,
        log_data.notes,
        log_data.interruptions,
        log_data.interruption_minutes,
        log_data.tasks,
        log_data.session_type,
        log_data.planned_duration_minutes,
        log_data.focus_rating,
        log_data.energy_level,
        log_data.context_switches,
        log_data.defects,
        log_data.deliverables,
        log_data.blockers,
        log_data.retrospective
      )
    end
  end
  
  return M.Project.new(project_info, structure, task_list, time_log, data.tags, data.notes)
end

return M
