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

-- Task model
-- JSON: {
--   "name": "name",
--   "details": "description",
--   "estimation": "",
--   "tags": ["",""]
-- }
M.Task = {}
M.Task.__index = M.Task

function M.Task.new(id, name, details, estimation, tags)
  local self = setmetatable({}, M.Task)
  self.id = id or ""
  self.name = name or ""
  self.details = details or ""
  self.estimation = estimation or ""
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
--   "tasks": ["links to task_list"]
-- }
M.TimeLog = {}
M.TimeLog.__index = M.TimeLog

function M.TimeLog.new(start_timestamp, end_timestamp, notes, interruptions, interruption_minutes, tasks)
  local self = setmetatable({}, M.TimeLog)
  self.start_timestamp = start_timestamp or ""
  self.end_timestamp = end_timestamp or ""
  self.notes = notes or ""
  self.interruptions = interruptions or ""
  self.interruption_minutes = interruption_minutes or 0
  self.tasks = tasks or {}  -- array of task IDs
  return self
end

-- Project model (root level)
-- JSON: { "project_info": {...}, "structure": {...}, "task_list": {...}, "time_log": [...], "tags": [...] }
M.Project = {}
M.Project.__index = M.Project

function M.Project.new(project_info, structure, task_list, time_log, tags)
  local self = setmetatable({}, M.Project)
  self.project_info = project_info or M.ProjectInfo.new()
  self.structure = structure or {}
  self.task_list = task_list or {}
  self.time_log = time_log or {}
  self.tags = tags or {}
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
      task_list[id] = M.Task.new(
        id,
        task_data.name,
        task_data.details,
        task_data.estimation,
        task_data.tags
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
        log_data.tasks
      )
    end
  end
  
  return M.Project.new(project_info, structure, task_list, time_log, data.tags)
end

return M
