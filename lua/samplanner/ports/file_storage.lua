-- File-based storage implementation for projects
local models = require('samplanner.domain.models')

local M = {}

-- Helper function to convert Project model to JSON-serializable table
local function project_to_table(project)
  -- Convert project_info
  local project_info = {
    id = project.project_info.id,
    name = project.project_info.name
  }

  -- Convert structure nodes recursively
  local function structure_node_to_table(node)
    local result = {
      type = node.type
    }
    if node.subtasks and next(node.subtasks) then
      result.subtasks = {}
      for id, subtask in pairs(node.subtasks) do
        result.subtasks[id] = structure_node_to_table(subtask)
      end
    end
    return result
  end

  local structure = {}
  for id, node in pairs(project.structure) do
    structure[id] = structure_node_to_table(node)
  end

  -- Convert task_list
  local task_list = {}
  for id, task in pairs(project.task_list) do
    local estimation_data = nil
    if task.estimation then
      estimation_data = {
        work_type = task.estimation.work_type,
        assumptions = task.estimation.assumptions,
        effort = task.estimation.effort,
        confidence = task.estimation.confidence,
        schedule = task.estimation.schedule,
        post_estimate_notes = task.estimation.post_estimate_notes,
      }
    end

    task_list[id] = {
      name = task.name,
      details = task.details,
      estimation = estimation_data,
      notes = task.notes ~= "" and task.notes or nil,
      tags = task.tags
    }
  end

  -- Convert time_log
  local time_log = {}
  for i, log in ipairs(project.time_log) do
    time_log[i] = {
      start_timestamp = log.start_timestamp,
      end_timestamp = log.end_timestamp,
      notes = log.notes,
      interruptions = log.interruptions,
      interruption_minutes = log.interruption_minutes,
      tasks = log.tasks,
      session_type = log.session_type,
      planned_duration_minutes = log.planned_duration_minutes,
      focus_rating = log.focus_rating,
      energy_level = log.energy_level,
      context_switches = log.context_switches,
      defects = log.defects,
      deliverables = log.deliverables,
      blockers = log.blockers,
      retrospective = log.retrospective
    }
  end

  return {
    project_info = project_info,
    structure = structure,
    task_list = task_list,
    time_log = time_log,
    tags = project.tags,
    notes = project.notes ~= "" and project.notes or nil
  }
end

-- Saves a project to storage
-- @param project: Project - The project model to save
-- @param directory: string - The directory path where the project should be saved
-- @return boolean, string - success status and error message if failed
function M.save(project, directory)
  -- Ensure directory exists
  vim.fn.mkdir(directory, "p")

  -- Create filename from project name
  local filename = project.project_info.name .. ".json"
  local filepath = directory .. "/" .. filename

  -- Convert project to table
  local data = project_to_table(project)

  -- Encode to JSON
  local json_str = vim.fn.json_encode(data)
  if not json_str then
    return false, "Failed to encode project to JSON"
  end

  -- Write to file
  local file, err = io.open(filepath, "w")
  if not file then
    return false, "Failed to open file for writing: " .. (err or "unknown error")
  end

  file:write(json_str)
  file:close()

  return true, nil
end

-- Loads a project from storage
-- This function never fails - it always returns a valid project.
-- If the file doesn't exist, a new empty project is created.
-- If the file can't be parsed, the raw content is preserved in the project notes.
-- @param project_name: string - The name of the project to load
-- @param directory: string - The directory path where the project is stored
-- @return Project, string|nil - the loaded project, and optional warning message
function M.load(project_name, directory)
  local filename = project_name .. ".json"
  local filepath = directory .. "/" .. filename

  -- Read file - if it doesn't exist, create a new empty project
  local file, err = io.open(filepath, "r")
  if not file then
    local project_info = models.ProjectInfo.new("", project_name)
    local project = models.Project.new(project_info, {}, {}, {}, {}, "")
    return project, "Created new project (file did not exist)"
  end

  local content = file:read("*all")
  file:close()

  -- Handle empty file
  if not content or content == "" then
    local project_info = models.ProjectInfo.new("", project_name)
    local project = models.Project.new(project_info, {}, {}, {}, {}, "")
    return project, "Created new project (file was empty)"
  end

  -- Decode JSON - if it fails, preserve raw content in notes
  local ok, data = pcall(vim.fn.json_decode, content)
  if not ok or not data then
    local project_info = models.ProjectInfo.new("", project_name)
    local notes = "=== RECOVERED DATA (could not parse JSON) ===\n" .. content
    local project = models.Project.new(project_info, {}, {}, {}, {}, notes)
    return project, "Created new project with recovered data (JSON parse failed)"
  end

  -- Convert to Project model
  local project = models.Project.from_table(data)

  return project, nil
end

-- Lists all available projects in a directory
-- @param directory: string - The directory path to search for projects
-- @return table - array of project names (without .json extension)
function M.list_projects(directory)
  local projects = {}

  -- Check if directory exists
  if vim.fn.isdirectory(directory) == 0 then
    return projects
  end

  -- List all .json files in directory
  local files = vim.fn.glob(directory .. "/*.json", false, true)

  for _, filepath in ipairs(files) do
    -- Extract filename without extension
    local filename = vim.fn.fnamemodify(filepath, ":t:r")
    table.insert(projects, filename)
  end

  return projects
end

return M
