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
    task_list[id] = {
      name = task.name,
      details = task.details,
      estimation = task.estimation,
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
      tasks = log.tasks
    }
  end

  return {
    project_info = project_info,
    structure = structure,
    task_list = task_list,
    time_log = time_log,
    tags = project.tags
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
-- @param project_name: string - The name of the project to load
-- @param directory: string - The directory path where the project is stored
-- @return Project, string - the loaded project or nil, and error message if failed
function M.load(project_name, directory)
  local filename = project_name .. ".json"
  local filepath = directory .. "/" .. filename

  -- Read file
  local file, err = io.open(filepath, "r")
  if not file then
    return nil, "Failed to open file for reading: " .. (err or "unknown error")
  end

  local content = file:read("*all")
  file:close()

  -- Decode JSON
  local ok, data = pcall(vim.fn.json_decode, content)
  if not ok or not data then
    return nil, "Failed to decode JSON from file"
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
