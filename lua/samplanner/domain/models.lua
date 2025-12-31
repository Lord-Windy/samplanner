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
--   "assumptions": ["assumption 1", "assumption 2"],
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
--     "could_be_smaller": [""],
--     "could_be_bigger": [""],
--     "ignored_last_time": [""]
--   }
-- }
M.Estimation = {}
M.Estimation.__index = M.Estimation

function M.Estimation.new(data)
  data = data or {}
  local self = setmetatable({}, M.Estimation)
  self.work_type = data.work_type or ""
  self.assumptions = data.assumptions or {}
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
  self.post_estimate_notes = {
    could_be_smaller = data.post_estimate_notes and data.post_estimate_notes.could_be_smaller or {},
    could_be_bigger = data.post_estimate_notes and data.post_estimate_notes.could_be_bigger or {},
    ignored_last_time = data.post_estimate_notes and data.post_estimate_notes.ignored_last_time or {},
  }
  return self
end

-- Check if estimation has any meaningful data
function M.Estimation:is_empty()
  return self.work_type == ""
    and #self.assumptions == 0
    and self.effort.method == ""
    and self.effort.base_hours == 0
    and self.confidence == ""
    and self.schedule.start_date == ""
    and self.schedule.target_finish == ""
    and #self.schedule.milestones == 0
    and #self.post_estimate_notes.could_be_smaller == 0
    and #self.post_estimate_notes.could_be_bigger == 0
    and #self.post_estimate_notes.ignored_last_time == 0
end

-- Task model
-- JSON: {
--   "name": "name",
--   "details": "description",
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
  self.details = details or ""
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

      task_list[id] = M.Task.new(
        id,
        task_data.name,
        task_data.details,
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
        log_data.tasks
      )
    end
  end
  
  return M.Project.new(project_info, structure, task_list, time_log, data.tags, data.notes)
end

return M
