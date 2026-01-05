local M = {}

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
  self.work_type = data.work_type or ""

  -- Handle both old array format and new string format for assumptions
  if type(data.assumptions) == "table" then
    local helpers = require('samplanner.migrations.array_string_helpers')
    self.assumptions = helpers.array_to_text(data.assumptions)
  else
    self.assumptions = data.assumptions or ""
  end

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

  -- Handle both old array format and new string format for post_estimate_notes
  local helpers = require('samplanner.migrations.array_string_helpers')
  local pen = data.post_estimate_notes or {}
  self.post_estimate_notes = {
    could_be_smaller = type(pen.could_be_smaller) == "table" and helpers.array_to_text(pen.could_be_smaller) or pen.could_be_smaller or "",
    could_be_bigger = type(pen.could_be_bigger) == "table" and helpers.array_to_text(pen.could_be_bigger) or pen.could_be_bigger or "",
    ignored_last_time = type(pen.ignored_last_time) == "table" and helpers.array_to_text(pen.ignored_last_time) or pen.ignored_last_time or "",
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

  -- Handle both old array format and new string format
  self.outcome_dod = type(data.outcome_dod) == "table" and helpers.array_to_text(data.outcome_dod) or data.outcome_dod or ""
  self.scope_in = type(data.scope_in) == "table" and helpers.array_to_text(data.scope_in) or data.scope_in or ""
  self.scope_out = type(data.scope_out) == "table" and helpers.array_to_text(data.scope_out) or data.scope_out or ""
  self.requirements_constraints = type(data.requirements_constraints) == "table" and helpers.array_to_text(data.requirements_constraints) or data.requirements_constraints or ""
  self.dependencies = type(data.dependencies) == "table" and helpers.array_to_text(data.dependencies) or data.dependencies or ""
  self.approach = type(data.approach) == "table" and helpers.array_to_text(data.approach) or data.approach or ""
  self.risks = type(data.risks) == "table" and helpers.array_to_text(data.risks) or data.risks or ""
  self.validation_test_plan = type(data.validation_test_plan) == "table" and helpers.array_to_text(data.validation_test_plan) or data.validation_test_plan or ""

  self.completed = data.completed or false
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

  -- Handle both old array format and new string format
  self.capabilities = type(data.capabilities) == "table" and helpers.array_to_text(data.capabilities) or data.capabilities or ""
  self.acceptance_criteria = type(data.acceptance_criteria) == "table" and helpers.array_to_text(data.acceptance_criteria) or data.acceptance_criteria or ""
  self.architecture_design = type(data.architecture_design) == "table" and helpers.array_to_text(data.architecture_design) or data.architecture_design or ""
  self.interfaces_integration = type(data.interfaces_integration) == "table" and helpers.array_to_text(data.interfaces_integration) or data.interfaces_integration or ""
  self.quality_attributes = type(data.quality_attributes) == "table" and helpers.array_to_text(data.quality_attributes) or data.quality_attributes or ""
  self.related_components = type(data.related_components) == "table" and helpers.array_to_text(data.related_components) or data.related_components or ""

  self.other = data.other or ""
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

  -- Handle both old array format and new string format
  self.goals_objectives = type(data.goals_objectives) == "table" and helpers.array_to_text(data.goals_objectives) or data.goals_objectives or ""
  self.scope_boundaries = type(data.scope_boundaries) == "table" and helpers.array_to_text(data.scope_boundaries) or data.scope_boundaries or ""
  self.key_components = type(data.key_components) == "table" and helpers.array_to_text(data.key_components) or data.key_components or ""
  self.success_metrics = type(data.success_metrics) == "table" and helpers.array_to_text(data.success_metrics) or data.success_metrics or ""
  self.stakeholders = type(data.stakeholders) == "table" and helpers.array_to_text(data.stakeholders) or data.stakeholders or ""
  self.dependencies_constraints = type(data.dependencies_constraints) == "table" and helpers.array_to_text(data.dependencies_constraints) or data.dependencies_constraints or ""

  self.strategic_context = data.strategic_context or ""
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

function M.Task.new(id, name, details, estimation, tags, notes)
  local self = setmetatable({}, M.Task)
  self.id = id or ""
  self.name = name or ""
  -- details can be AreaDetails (for Area) or JobDetails (for Job) or ComponentDetails (for Component)
  if details and type(details) == "table" and getmetatable(details) == M.JobDetails then
    self.details = details
  elseif details and type(details) == "table" and getmetatable(details) == M.ComponentDetails then
    self.details = details
  elseif details and type(details) == "table" and getmetatable(details) == M.AreaDetails then
    self.details = details
  elseif details and type(details) == "table" then
    -- Try to determine which type of details this should be
    -- Check for JobDetails fields
    local has_job_fields = details.context_why ~= nil or details.outcome_dod ~= nil or details.approach ~= nil
    -- Check for ComponentDetails fields
    local has_component_fields = details.purpose ~= nil or details.capabilities ~= nil or details.acceptance_criteria ~= nil
    -- Check for AreaDetails fields
    local has_area_fields = details.vision_purpose ~= nil or details.goals_objectives ~= nil or details.key_components ~= nil

    if has_job_fields then
      self.details = M.JobDetails.new(details)
    elseif has_component_fields then
      self.details = M.ComponentDetails.new(details)
    elseif has_area_fields then
      self.details = M.AreaDetails.new(details)
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

  -- Handle both old array format and new string format for defects
  local def = defects or {}
  if type(def) == "table" then
    self.defects = {
      found = type(def.found) == "table" and helpers.array_to_text(def.found) or def.found or "",
      fixed = type(def.fixed) == "table" and helpers.array_to_text(def.fixed) or def.fixed or "",
    }
  else
    self.defects = { found = "", fixed = "" }
  end

  -- Handle both old array format and new string format for deliverables and blockers
  self.deliverables = type(deliverables) == "table" and helpers.array_to_text(deliverables) or deliverables or ""
  self.blockers = type(blockers) == "table" and helpers.array_to_text(blockers) or blockers or ""

  -- Handle both old array format and new string format for retrospective
  local retro = retrospective or {}
  if type(retro) == "table" then
    self.retrospective = {
      what_went_well = type(retro.what_went_well) == "table" and helpers.array_to_text(retro.what_went_well) or retro.what_went_well or "",
      what_needs_improvement = type(retro.what_needs_improvement) == "table" and helpers.array_to_text(retro.what_needs_improvement) or retro.what_needs_improvement or "",
      lessons_learned = type(retro.lessons_learned) == "table" and helpers.array_to_text(retro.lessons_learned) or retro.lessons_learned or "",
    }
  else
    self.retrospective = { what_went_well = "", what_needs_improvement = "", lessons_learned = "" }
  end

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

-- Helper function to validate and migrate details based on node type
local function validate_and_migrate_details(task_data, node_type, notes)
  local details = task_data.details

  -- If node type is Job, details should be a JobDetails structure
  if node_type == "Job" then
    -- If details doesn't exist, create empty JobDetails
    if not details then
      return M.JobDetails.new(), notes
    end

    -- If details is a table with proper JobDetails structure, use it
    if type(details) == "table" then
      -- Check if it conforms to JobDetails structure
      local has_job_details_fields = details.context_why ~= nil
        or details.outcome_dod ~= nil
        or details.scope_in ~= nil

      if has_job_details_fields then
        return M.JobDetails.new(details), notes
      else
        -- Table but not conforming structure - migrate to notes
        local detail_str = vim.inspect(details)
        if notes ~= "" then
          notes = "Migrated details:\n" .. detail_str .. "\n\n" .. notes
        else
          notes = "Migrated details:\n" .. detail_str
        end
        return M.JobDetails.new(), notes
      end
    end

    -- If details is a string (old format), migrate to notes
    if type(details) == "string" and details ~= "" then
      if notes ~= "" then
        notes = "Migrated details:\n" .. details .. "\n\n" .. notes
      else
        notes = "Migrated details:\n" .. details
      end
      return M.JobDetails.new(), notes
    end

    -- Default: empty JobDetails
    return M.JobDetails.new(), notes
  elseif node_type == "Component" then
    -- If node type is Component, details should be a ComponentDetails structure
    -- If details doesn't exist, create empty ComponentDetails
    if not details then
      return M.ComponentDetails.new(), notes
    end

    -- If details is a table with proper ComponentDetails structure, use it
    if type(details) == "table" then
      -- Check if it conforms to ComponentDetails structure
      local has_component_details_fields = details.purpose ~= nil
        or details.capabilities ~= nil
        or details.acceptance_criteria ~= nil

      if has_component_details_fields then
        return M.ComponentDetails.new(details), notes
      else
        -- Table but not conforming structure - migrate to notes
        local detail_str = vim.inspect(details)
        if notes ~= "" then
          notes = "Migrated details:\n" .. detail_str .. "\n\n" .. notes
        else
          notes = "Migrated details:\n" .. detail_str
        end
        return M.ComponentDetails.new(), notes
      end
    end

    -- If details is a string (old format), migrate to notes
    if type(details) == "string" and details ~= "" then
      if notes ~= "" then
        notes = "Migrated details:\n" .. details .. "\n\n" .. notes
      else
        notes = "Migrated details:\n" .. details
      end
      return M.ComponentDetails.new(), notes
    end

    -- Default: empty ComponentDetails
    return M.ComponentDetails.new(), notes
  else
    -- For Area, details should be an AreaDetails structure
    -- If details doesn't exist, create empty AreaDetails
    if not details then
      return M.AreaDetails.new(), notes
    end

    -- If details is a table with proper AreaDetails structure, use it
    if type(details) == "table" then
      -- Check if it conforms to AreaDetails structure
      local has_area_details_fields = details.vision_purpose ~= nil
        or details.goals_objectives ~= nil
        or details.key_components ~= nil

      if has_area_details_fields then
        return M.AreaDetails.new(details), notes
      else
        -- Table but not conforming structure - migrate to notes
        local detail_str = vim.inspect(details)
        if notes ~= "" then
          notes = "Migrated details:\n" .. detail_str .. "\n\n" .. notes
        else
          notes = "Migrated details:\n" .. detail_str
        end
        return M.AreaDetails.new(), notes
      end
    end

    -- If details is a string (old format), migrate to notes
    if type(details) == "string" and details ~= "" then
      if notes ~= "" then
        notes = "Migrated details:\n" .. details .. "\n\n" .. notes
      else
        notes = "Migrated details:\n" .. details
      end
      return M.AreaDetails.new(), notes
    end

    -- Default: empty AreaDetails
    return M.AreaDetails.new(), notes
  end
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
        notes
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
