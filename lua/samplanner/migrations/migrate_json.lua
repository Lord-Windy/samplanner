-- Migration script to convert between array and string formats in JSON files
-- This script can be run standalone or used programmatically

local helpers = require('samplanner.migrations.array_string_helpers')

local M = {}

-- Field definitions for each model type
local ESTIMATION_ARRAY_FIELDS = {
  "assumptions",
}

local ESTIMATION_NESTED_FIELDS = {
  post_estimate_notes = {
    "could_be_smaller",
    "could_be_bigger",
    "ignored_last_time",
  }
}

local JOB_DETAILS_ARRAY_FIELDS = {
  "outcome_dod",
  "scope_in",
  "scope_out",
  "requirements_constraints",
  "dependencies",
  "approach",
  "risks",
  "validation_test_plan",
}

local COMPONENT_DETAILS_ARRAY_FIELDS = {
  "capabilities",
  "acceptance_criteria",
  "architecture_design",
  "interfaces_integration",
  "quality_attributes",
  "related_components",
}

local AREA_DETAILS_ARRAY_FIELDS = {
  "goals_objectives",
  "scope_boundaries",
  "key_components",
  "success_metrics",
  "stakeholders",
  "dependencies_constraints",
}

local TIME_LOG_ARRAY_FIELDS = {
  "deliverables",
  "blockers",
}

local TIME_LOG_NESTED_FIELDS = {
  defects = {
    "found",
    "fixed",
  },
  retrospective = {
    "what_went_well",
    "what_needs_improvement",
    "lessons_learned",
  }
}

-- Migrate estimation object
local function migrate_estimation(estimation, to_strings)
  if not estimation or type(estimation) ~= "table" then
    return estimation
  end

  local result = vim.deepcopy(estimation)

  if to_strings then
    result = helpers.migrate_arrays_to_strings(result, ESTIMATION_ARRAY_FIELDS)

    -- Handle nested fields
    if result.post_estimate_notes and type(result.post_estimate_notes) == "table" then
      result.post_estimate_notes = helpers.migrate_arrays_to_strings(
        result.post_estimate_notes,
        ESTIMATION_NESTED_FIELDS.post_estimate_notes
      )
    end
  else
    result = helpers.migrate_strings_to_arrays(result, ESTIMATION_ARRAY_FIELDS)

    -- Handle nested fields
    if result.post_estimate_notes and type(result.post_estimate_notes) == "table" then
      result.post_estimate_notes = helpers.migrate_strings_to_arrays(
        result.post_estimate_notes,
        ESTIMATION_NESTED_FIELDS.post_estimate_notes
      )
    end
  end

  return result
end

-- Migrate task details based on type
local function migrate_task_details(details, task_type, to_strings)
  if not details or type(details) ~= "table" then
    return details
  end

  local result = vim.deepcopy(details)
  local fields = {}

  if task_type == "Job" then
    fields = JOB_DETAILS_ARRAY_FIELDS
  elseif task_type == "Component" then
    fields = COMPONENT_DETAILS_ARRAY_FIELDS
  elseif task_type == "Area" then
    fields = AREA_DETAILS_ARRAY_FIELDS
  else
    return result
  end

  if to_strings then
    return helpers.migrate_arrays_to_strings(result, fields)
  else
    return helpers.migrate_strings_to_arrays(result, fields)
  end
end

-- Migrate a single task
local function migrate_task(task, task_type, to_strings)
  if not task or type(task) ~= "table" then
    return task
  end

  local result = vim.deepcopy(task)

  -- Migrate estimation (for Jobs only)
  if task_type == "Job" and result.estimation then
    result.estimation = migrate_estimation(result.estimation, to_strings)
  end

  -- Migrate details
  if result.details and type(result.details) == "table" then
    result.details = migrate_task_details(result.details, task_type, to_strings)
  end

  return result
end

-- Migrate a time log entry
local function migrate_time_log(time_log, to_strings)
  if not time_log or type(time_log) ~= "table" then
    return time_log
  end

  local result = vim.deepcopy(time_log)

  if to_strings then
    result = helpers.migrate_arrays_to_strings(result, TIME_LOG_ARRAY_FIELDS)

    -- Handle nested fields
    if result.defects and type(result.defects) == "table" then
      result.defects = helpers.migrate_arrays_to_strings(
        result.defects,
        TIME_LOG_NESTED_FIELDS.defects
      )
    end

    if result.retrospective and type(result.retrospective) == "table" then
      result.retrospective = helpers.migrate_arrays_to_strings(
        result.retrospective,
        TIME_LOG_NESTED_FIELDS.retrospective
      )
    end
  else
    result = helpers.migrate_strings_to_arrays(result, TIME_LOG_ARRAY_FIELDS)

    -- Handle nested fields
    if result.defects and type(result.defects) == "table" then
      result.defects = helpers.migrate_strings_to_arrays(
        result.defects,
        TIME_LOG_NESTED_FIELDS.defects
      )
    end

    if result.retrospective and type(result.retrospective) == "table" then
      result.retrospective = helpers.migrate_strings_to_arrays(
        result.retrospective,
        TIME_LOG_NESTED_FIELDS.retrospective
      )
    end
  end

  -- Keep tasks as array (it's a list of task IDs)
  return result
end

-- Get task type from structure
local function get_task_type(structure, task_id)
  local function search(nodes, id)
    for node_id, node in pairs(nodes or {}) do
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

-- Migrate a complete project JSON
-- @param project_data: table - The parsed JSON project data
-- @param to_strings: boolean - true to convert arrays to strings, false to convert strings to arrays
-- @return table - Migrated project data
function M.migrate_project(project_data, to_strings)
  if not project_data or type(project_data) ~= "table" then
    return project_data
  end

  local result = vim.deepcopy(project_data)

  -- Migrate task_list
  if result.task_list then
    for task_id, task in pairs(result.task_list) do
      local task_type = get_task_type(result.structure, task_id)
      result.task_list[task_id] = migrate_task(task, task_type, to_strings)
    end
  end

  -- Migrate time_log
  if result.time_log then
    for i, log_entry in ipairs(result.time_log) do
      result.time_log[i] = migrate_time_log(log_entry, to_strings)
    end
  end

  return result
end

-- Migrate a JSON file from arrays to strings
-- @param input_file: string - Path to input JSON file
-- @param output_file: string|nil - Path to output JSON file (defaults to input_file)
function M.migrate_file_to_strings(input_file, output_file)
  output_file = output_file or input_file

  -- Read JSON file
  local file = io.open(input_file, "r")
  if not file then
    error("Failed to open input file: " .. input_file)
  end

  local content = file:read("*all")
  file:close()

  -- Parse JSON
  local project_data = vim.json.decode(content)

  -- Migrate to strings
  local migrated_data = M.migrate_project(project_data, true)

  -- Write back to file
  local output = io.open(output_file, "w")
  if not output then
    error("Failed to open output file: " .. output_file)
  end

  output:write(vim.json.encode(migrated_data))
  output:close()

  print("Migrated " .. input_file .. " to string format -> " .. output_file)
end

-- Migrate a JSON file from strings to arrays
-- @param input_file: string - Path to input JSON file
-- @param output_file: string|nil - Path to output JSON file (defaults to input_file)
function M.migrate_file_to_arrays(input_file, output_file)
  output_file = output_file or input_file

  -- Read JSON file
  local file = io.open(input_file, "r")
  if not file then
    error("Failed to open input file: " .. input_file)
  end

  local content = file:read("*all")
  file:close()

  -- Parse JSON
  local project_data = vim.json.decode(content)

  -- Migrate to arrays
  local migrated_data = M.migrate_project(project_data, false)

  -- Write back to file
  local output = io.open(output_file, "w")
  if not output then
    error("Failed to open output file: " .. output_file)
  end

  output:write(vim.json.encode(migrated_data))
  output:close()

  print("Migrated " .. input_file .. " to array format -> " .. output_file)
end

return M
