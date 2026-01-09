-- Core domain operations for Samplanner
local models = require('samplanner.domain.models')
local file_storage = require('samplanner.ports.file_storage')
local table_utils = require('samplanner.utils.table')

local M = {}

-- Local alias for sorted_keys
local sorted_keys = table_utils.sorted_keys

-- Helper to update IDs recursively for a node and its children
-- @param node: StructureNode - The node to update
-- @param old_id: string - The old ID
-- @param new_id: string - The new ID
-- @param task_list: table - The project's task_list to update
-- @param temp_tasks: table|nil - Optional temp storage for tasks (used during swap)
local function update_ids_recursive(node, old_id, new_id, task_list, temp_tasks)
  -- Update associated task ID
  local task_source = temp_tasks or task_list
  if task_source[old_id] then
    local task = task_source[old_id]
    task.id = new_id
    task_list[new_id] = task
    if not temp_tasks then
      task_list[old_id] = nil
    end
  end

  -- Update children
  if node.subtasks then
    local new_subtasks = {}
    for child_id, child_node in pairs(node.subtasks) do
      local suffix = child_id:sub(#old_id + 2)  -- +2 to skip the dot
      local new_child_id = new_id .. "." .. suffix
      child_node.id = new_child_id
      new_subtasks[new_child_id] = child_node
      update_ids_recursive(child_node, child_id, new_child_id, task_list, temp_tasks)
    end
    node.subtasks = new_subtasks
  end
end

-- Default storage directory (can be overridden via config)
local function get_storage_dir()
  local samplanner = require('samplanner')
  return samplanner.config and samplanner.config.filepath or vim.fn.expand("~") .. "/Dropbox/planning"
end

--------------------------------------------------------------------------------
-- 1.1 Project Management
--------------------------------------------------------------------------------

-- Create a new project and save to storage
-- @param id: string - Project ID
-- @param name: string - Project name
-- @return Project, string - the created project or nil, and error message if failed
function M.create_project(id, name)
  local project_info = models.ProjectInfo.new(id, name)
  local project = models.Project.new(project_info, {}, {}, {}, {})

  local success, err = file_storage.save(project, get_storage_dir())
  if not success then
    return nil, err
  end

  return project, nil
end

-- Load existing project from storage
-- @param name: string - Project name
-- @return Project, string - the loaded project or nil, and error message if failed
function M.load_project(name)
  return file_storage.load(name, get_storage_dir())
end

-- Remove project from storage
-- @param name: string - Project name
-- @return boolean, string - success status and error message if failed
function M.delete_project(name)
  local filepath = get_storage_dir() .. "/" .. name .. ".json"
  local ok, err = os.remove(filepath)
  if not ok then
    return false, "Failed to delete project: " .. (err or "unknown error")
  end
  return true, nil
end

-- Save a project to storage (helper for other operations)
-- @param project: Project - The project to save
-- @return boolean, string - success status and error message if failed
function M.save_project(project)
  return file_storage.save(project, get_storage_dir())
end

--------------------------------------------------------------------------------
-- 1.2 Tree Structure Operations
--------------------------------------------------------------------------------

-- Helper: Generate next sibling number at a given level
local function get_next_sibling_number(parent_subtasks)
  local max_num = 0
  for id, _ in pairs(parent_subtasks) do
    -- Extract the last number from the ID (e.g., "1.2.3" -> 3)
    local num = tonumber(id:match("(%d+)$"))
    if num and num > max_num then
      max_num = num
    end
  end
  return max_num + 1
end

-- Helper: Find a node and its parent by ID
-- Returns: node, parent_subtasks_table, parent_id
local function find_node(structure, node_id)
  -- Check top-level nodes
  if structure[node_id] then
    return structure[node_id], structure, nil
  end

  -- Recursive search
  local function search(subtasks, parent_id)
    for id, node in pairs(subtasks) do
      if id == node_id then
        return node, subtasks, parent_id
      end
      if node.subtasks and next(node.subtasks) then
        local found, parent_table, pid = search(node.subtasks, id)
        if found then
          return found, parent_table, pid
        end
      end
    end
    return nil, nil, nil
  end

  for id, node in pairs(structure) do
    if node.subtasks and next(node.subtasks) then
      local found, parent_table, pid = search(node.subtasks, id)
      if found then
        return found, parent_table, pid
      end
    end
  end

  return nil, nil, nil
end

-- Add node at any position in tree
-- @param project: Project - The project to modify
-- @param parent_id: string|nil - Parent node ID (nil for root level)
-- @param node_type: string - "Area", "Component", or "Job"
-- @param name: string - Node name (stored in associated task if needed)
-- @return string, string - the new node ID or nil, and error message if failed
function M.add_node(project, parent_id, node_type, name)
  local parent_subtasks
  local new_id

  if parent_id == nil then
    -- Add to root level
    parent_subtasks = project.structure
    local next_num = get_next_sibling_number(parent_subtasks)
    new_id = tostring(next_num)
  else
    -- Find parent node
    local parent_node = find_node(project.structure, parent_id)
    if not parent_node then
      return nil, "Parent node not found: " .. parent_id
    end

    if not parent_node.subtasks then
      parent_node.subtasks = {}
    end
    parent_subtasks = parent_node.subtasks
    local next_num = get_next_sibling_number(parent_subtasks)
    new_id = parent_id .. "." .. next_num
  end

  -- Create the new node
  local new_node = models.StructureNode.new(new_id, node_type, {})
  parent_subtasks[new_id] = new_node

  -- If name is provided, create an associated task
  if name and name ~= "" then
    local task = models.Task.new(new_id, name, "", nil, {}, "")
    project.task_list[new_id] = task
  end

  -- Save the project
  local success, err = M.save_project(project)
  if not success then
    return nil, err
  end

  return new_id, nil
end

-- Remove node and its children
-- @param project: Project - The project to modify
-- @param node_id: string - The node ID to remove
-- @return boolean, string - success status and error message if failed
function M.remove_node(project, node_id)
  local node, parent_subtasks, _ = find_node(project.structure, node_id)
  if not node then
    return false, "Node not found: " .. node_id
  end

  -- Helper to collect all descendant IDs for cleanup
  local function collect_ids(n, id, ids)
    table.insert(ids, id)
    if n.subtasks then
      for child_id, child_node in pairs(n.subtasks) do
        collect_ids(child_node, child_id, ids)
      end
    end
  end

  -- Collect all IDs that will be removed
  local ids_to_remove = {}
  collect_ids(node, node_id, ids_to_remove)

  -- Remove associated tasks
  for _, id in ipairs(ids_to_remove) do
    project.task_list[id] = nil
  end

  -- Remove the node from parent
  parent_subtasks[node_id] = nil

  -- Save the project
  local success, err = M.save_project(project)
  if not success then
    return false, err
  end

  return true, nil
end

-- Relocate node in tree
-- @param project: Project - The project to modify
-- @param node_id: string - The node ID to move
-- @param new_parent_id: string|nil - New parent ID (nil for root level)
-- @return string, string - the new node ID or nil, and error message if failed
function M.move_node(project, node_id, new_parent_id)
  -- Find the node to move
  local node, old_parent_subtasks, _ = find_node(project.structure, node_id)
  if not node then
    return nil, "Node not found: " .. node_id
  end

  -- Determine new parent subtasks table
  local new_parent_subtasks
  local new_id

  if new_parent_id == nil then
    new_parent_subtasks = project.structure
    local next_num = get_next_sibling_number(new_parent_subtasks)
    new_id = tostring(next_num)
  else
    local new_parent = find_node(project.structure, new_parent_id)
    if not new_parent then
      return nil, "New parent not found: " .. new_parent_id
    end

    if not new_parent.subtasks then
      new_parent.subtasks = {}
    end
    new_parent_subtasks = new_parent.subtasks
    local next_num = get_next_sibling_number(new_parent_subtasks)
    new_id = new_parent_id .. "." .. next_num
  end

  -- Remove from old parent
  old_parent_subtasks[node_id] = nil

  -- Update node and its children IDs
  node.id = new_id
  update_ids_recursive(node, node_id, new_id, project.task_list)

  -- Add to new parent
  new_parent_subtasks[new_id] = node

  -- Save the project
  local success, err = M.save_project(project)
  if not success then
    return nil, err
  end

  return new_id, nil
end

-- Re-number all nodes for consistent ordering
-- @param project: Project - The project to modify
-- @return boolean, string - success status and error message if failed
function M.renumber_structure(project)
  -- Recursive function to renumber a level
  local function renumber_level(subtasks, prefix)
    local keys = sorted_keys(subtasks)
    local new_subtasks = {}

    for i, old_id in ipairs(keys) do
      local node = subtasks[old_id]
      local new_id = prefix == "" and tostring(i) or (prefix .. "." .. i)

      -- Update task ID if exists
      if project.task_list[old_id] then
        local task = project.task_list[old_id]
        task.id = new_id
        project.task_list[new_id] = task
        if old_id ~= new_id then
          project.task_list[old_id] = nil
        end
      end

      -- Renumber children
      if node.subtasks and next(node.subtasks) then
        node.subtasks = renumber_level(node.subtasks, new_id)
      end

      node.id = new_id
      new_subtasks[new_id] = node
    end

    return new_subtasks
  end

  project.structure = renumber_level(project.structure, "")

  -- Save the project
  local success, err = M.save_project(project)
  if not success then
    return false, err
  end

  return true, nil
end

-- Swap node with adjacent sibling
-- @param project: Project - The project to modify
-- @param node_id: string - The node ID to move
-- @param direction: string - "up" or "down"
-- @return boolean, string - success status and error message if failed
function M.swap_siblings(project, node_id, direction)
  local node, parent_subtasks, parent_id = find_node(project.structure, node_id)
  if not node then
    return false, "Node not found: " .. node_id
  end

  local siblings = sorted_keys(parent_subtasks)
  local current_index = nil
  for i, id in ipairs(siblings) do
    if id == node_id then
      current_index = i
      break
    end
  end

  if not current_index then
    return false, "Node not found in parent's children"
  end

  -- Check bounds
  local swap_index
  if direction == "up" then
    if current_index == 1 then
      return false, "Cannot move up: already at the top"
    end
    swap_index = current_index - 1
  elseif direction == "down" then
    if current_index == #siblings then
      return false, "Cannot move down: already at the bottom"
    end
    swap_index = current_index + 1
  else
    return false, "Invalid direction: " .. direction
  end

  -- Swap by renumbering
  local swap_id = siblings[swap_index]
  local prefix = parent_id and (parent_id .. ".") or ""

  -- Create temporary storage for the nodes
  local temp_nodes = {}
  for i, id in ipairs(siblings) do
    temp_nodes[i] = { id = id, node = parent_subtasks[id] }
  end

  -- Swap positions in our temp array
  temp_nodes[current_index], temp_nodes[swap_index] = temp_nodes[swap_index], temp_nodes[current_index]

  -- Helper to collect all IDs recursively (for cleanup)
  local function collect_all_ids(node, ids)
    table.insert(ids, node.id)
    if node.subtasks then
      for child_id, child_node in pairs(node.subtasks) do
        collect_all_ids(child_node, ids)
      end
    end
  end

  -- Collect all old IDs that need to be cleaned up
  local old_ids = {}
  for _, id in ipairs(siblings) do
    local node = parent_subtasks[id]
    collect_all_ids(node, old_ids)
  end

  -- Create temp copy of all task data
  local temp_tasks = {}
  for _, old_id in ipairs(old_ids) do
    if project.task_list[old_id] then
      temp_tasks[old_id] = project.task_list[old_id]
    end
  end

  -- Clear old task IDs
  for _, old_id in ipairs(old_ids) do
    project.task_list[old_id] = nil
  end

  -- Clear old parent subtasks
  for _, id in ipairs(siblings) do
    parent_subtasks[id] = nil
  end

  -- Reassign with new numbering
  for i, item in ipairs(temp_nodes) do
    local new_id = prefix .. i
    local node = item.node
    node.id = new_id
    update_ids_recursive(node, item.id, new_id, project.task_list, temp_tasks)
    parent_subtasks[new_id] = node
  end

  -- Save the project
  local success, err = M.save_project(project)
  if not success then
    return false, err
  end

  return true, nil
end

-- Move node under previous sibling (indent/demote)
-- @param project: Project - The project to modify
-- @param node_id: string - The node ID to indent
-- @return boolean, string - success status and error message if failed
function M.indent_node(project, node_id)
  local node, parent_subtasks, parent_id = find_node(project.structure, node_id)
  if not node then
    return false, "Node not found: " .. node_id
  end

  local siblings = sorted_keys(parent_subtasks)
  local current_index = nil
  for i, id in ipairs(siblings) do
    if id == node_id then
      current_index = i
      break
    end
  end

  if not current_index then
    return false, "Node not found in parent's children"
  end

  if current_index == 1 then
    return false, "Cannot indent: no previous sibling"
  end

  -- Get previous sibling
  local prev_sibling_id = siblings[current_index - 1]

  -- Move node under previous sibling
  local new_id, err = M.move_node(project, node_id, prev_sibling_id)
  if err then
    return false, err
  end

  -- Renumber to keep things clean
  local success, err2 = M.renumber_structure(project)
  if not success then
    return false, err2
  end

  return true, nil
end

-- Move node to parent's level (outdent/promote)
-- @param project: Project - The project to modify
-- @param node_id: string - The node ID to outdent
-- @return boolean, string - success status and error message if failed
function M.outdent_node(project, node_id)
  local node, parent_subtasks, parent_id = find_node(project.structure, node_id)
  if not node then
    return false, "Node not found: " .. node_id
  end

  if not parent_id then
    return false, "Cannot outdent: already at root level"
  end

  -- Get grandparent ID
  local grandparent_id = parent_id:match("^(.+)%.%d+$")

  -- Move node to grandparent level
  local new_id, err = M.move_node(project, node_id, grandparent_id)
  if err then
    return false, err
  end

  -- Renumber to keep things clean
  local success, err2 = M.renumber_structure(project)
  if not success then
    return false, err2
  end

  return true, nil
end

-- Render tree as formatted string for display
-- @param project: Project - The project to display
-- @return string - The formatted tree string
function M.get_tree_display(project)
  local lines = {}

  -- Recursive function to build display
  local function display_level(subtasks, depth)
    local keys = sorted_keys(subtasks)
    for _, id in ipairs(keys) do
      local node = subtasks[id]
      local indent = string.rep("  ", depth)
      local task = project.task_list[id]
      local name = task and task.name or ""

      local line = string.format("%s%s %s: %s", indent, id, node.type, name)
      table.insert(lines, line)

      if node.subtasks and next(node.subtasks) then
        display_level(node.subtasks, depth + 1)
      end
    end
  end

  display_level(project.structure, 0)

  return table.concat(lines, "\n")
end

--------------------------------------------------------------------------------
-- 1.3 Task Management
--------------------------------------------------------------------------------

-- Create detailed task
-- @param project: Project - The project to modify
-- @param id: string - Task ID
-- @param name: string - Task name
-- @param details: string - Task description
-- @param estimation: Estimation|nil - Structured estimation (for Jobs)
-- @param tags: table - Array of tags
-- @param notes: string - Additional notes
-- @return Task, string - the created task or nil, and error message if failed
function M.create_task(project, id, name, details, estimation, tags, notes)
  if project.task_list[id] then
    return nil, "Task already exists: " .. id
  end

  local task = models.Task.new(id, name, details or "", estimation, tags or {}, notes or "")
  project.task_list[id] = task

  -- Add any new tags to project
  if tags then
    for _, tag in ipairs(tags) do
      if not vim.tbl_contains(project.tags, tag) then
        table.insert(project.tags, tag)
      end
    end
  end

  -- Save the project
  local success, err = M.save_project(project)
  if not success then
    return nil, err
  end

  return task, nil
end

-- Modify existing task
-- @param project: Project - The project to modify
-- @param id: string - Task ID
-- @param updates: table - Fields to update {name?, details?, estimation?, notes?, tags?}
-- @return Task, string - the updated task or nil, and error message if failed
function M.update_task(project, id, updates)
  local task = project.task_list[id]
  if not task then
    return nil, "Task not found: " .. id
  end

  table_utils.apply_updates(task, updates, {"name", "details", "estimation", "notes", "tags", "custom"})

  -- Add any new tags to project
  if updates.tags ~= nil then
    for _, tag in ipairs(updates.tags) do
      if not vim.tbl_contains(project.tags, tag) then
        table.insert(project.tags, tag)
      end
    end
  end

  -- Save the project
  local success, err = M.save_project(project)
  if not success then
    return nil, err
  end

  return task, nil
end

-- Remove task from task_list
-- @param project: Project - The project to modify
-- @param id: string - Task ID
-- @return boolean, string - success status and error message if failed
function M.delete_task(project, id)
  if not project.task_list[id] then
    return false, "Task not found: " .. id
  end

  project.task_list[id] = nil

  -- Save the project
  local success, err = M.save_project(project)
  if not success then
    return false, err
  end

  return true, nil
end

-- Associate task with structure node
-- @param project: Project - The project to modify
-- @param task_id: string - Task ID
-- @param node_id: string - Structure node ID
-- @return boolean, string - success status and error message if failed
function M.link_task_to_node(project, task_id, node_id)
  local task = project.task_list[task_id]
  if not task then
    return false, "Task not found: " .. task_id
  end

  local node = find_node(project.structure, node_id)
  if not node then
    return false, "Node not found: " .. node_id
  end

  -- Move task to new ID (node_id)
  if task_id ~= node_id then
    task.id = node_id
    project.task_list[node_id] = task
    project.task_list[task_id] = nil
  end

  -- Save the project
  local success, err = M.save_project(project)
  if not success then
    return false, err
  end

  return true, nil
end

--------------------------------------------------------------------------------
-- 1.4 Time Log Operations
--------------------------------------------------------------------------------

-- Create new TimeLog with start_timestamp
-- @param project: Project - The project to modify
-- @return number, string - the session index or nil, and error message if failed
function M.start_session(project)
  local timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
  local session = models.TimeLog.new(
    timestamp,  -- start_timestamp
    "",         -- end_timestamp
    "",         -- notes
    "",         -- interruptions
    0,          -- interruption_minutes
    {},         -- tasks
    "",         -- session_type
    0,          -- planned_duration_minutes
    0,          -- focus_rating
    { start = 0, ["end"] = 0 },  -- energy_level
    0,          -- context_switches
    { found = {}, fixed = {} },  -- defects
    {},         -- deliverables
    {},         -- blockers
    { what_went_well = {}, what_needs_improvement = {}, lessons_learned = {} }  -- retrospective
  )

  table.insert(project.time_log, session)
  local session_index = #project.time_log

  -- Save the project
  local success, err = M.save_project(project)
  if not success then
    return nil, err
  end

  return session_index, nil
end

-- Set end_timestamp on active session
-- @param project: Project - The project to modify
-- @param session_index: number - The session index to stop
-- @return boolean, string - success status and error message if failed
function M.stop_session(project, session_index)
  local session = project.time_log[session_index]
  if not session then
    return false, "Session not found: " .. session_index
  end

  if session.end_timestamp ~= "" then
    return false, "Session already stopped"
  end

  session.end_timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")

  -- Save the project
  local success, err = M.save_project(project)
  if not success then
    return false, err
  end

  return true, nil
end

-- Modify session notes/interruptions
-- @param project: Project - The project to modify
-- @param session_index: number - The session index
-- @param updates: table - Fields to update {notes?, interruptions?, interruption_minutes?, session_type?, planned_duration_minutes?, focus_rating?, energy_level?, context_switches?, defects?, deliverables?, blockers?, retrospective?}
-- @return TimeLog, string - the updated session or nil, and error message if failed
function M.update_session(project, session_index, updates)
  local session = project.time_log[session_index]
  if not session then
    return nil, "Session not found: " .. session_index
  end

  table_utils.apply_updates(session, updates, {
    "notes", "interruptions", "interruption_minutes", "session_type",
    "planned_duration_minutes", "focus_rating", "energy_level", "context_switches",
    "defects", "deliverables", "blockers", "retrospective"
  })

  -- Save the project
  local success, err = M.save_project(project)
  if not success then
    return nil, err
  end

  return session, nil
end

-- Link task to session
-- @param project: Project - The project to modify
-- @param session_index: number - The session index
-- @param task_id: string - Task ID to add
-- @return boolean, string - success status and error message if failed
function M.add_task_to_session(project, session_index, task_id)
  local session = project.time_log[session_index]
  if not session then
    return false, "Session not found: " .. session_index
  end

  -- Check if task exists
  if not project.task_list[task_id] then
    return false, "Task not found: " .. task_id
  end

  -- Check if task already in session
  if vim.tbl_contains(session.tasks, task_id) then
    return true, nil  -- Already linked, not an error
  end

  table.insert(session.tasks, task_id)

  -- Save the project
  local success, err = M.save_project(project)
  if not success then
    return false, err
  end

  return true, nil
end

-- Find session without end_timestamp
-- @param project: Project - The project to search
-- @return number|nil, TimeLog|nil - the session index and session, or nil if none active
function M.get_active_session(project)
  for i, session in ipairs(project.time_log) do
    if session.end_timestamp == "" then
      return i, session
    end
  end
  return nil, nil
end

--------------------------------------------------------------------------------
-- 1.5 Tag Operations
--------------------------------------------------------------------------------

-- Add tag to project's tag list
-- @param project: Project - The project to modify
-- @param tag: string - Tag to add
-- @return boolean, string - success status and error message if failed
function M.add_tag(project, tag)
  if vim.tbl_contains(project.tags, tag) then
    return true, nil  -- Already exists, not an error
  end

  table.insert(project.tags, tag)

  -- Save the project
  local success, err = M.save_project(project)
  if not success then
    return false, err
  end

  return true, nil
end

-- Remove tag from project
-- @param project: Project - The project to modify
-- @param tag: string - Tag to remove
-- @return boolean, string - success status and error message if failed
function M.remove_tag(project, tag)
  -- Find and remove tag from project
  local found = false
  for i, t in ipairs(project.tags) do
    if t == tag then
      table.remove(project.tags, i)
      found = true
      break
    end
  end

  if not found then
    return false, "Tag not found: " .. tag
  end

  -- Also remove tag from all tasks
  for _, task in pairs(project.task_list) do
    for i, t in ipairs(task.tags) do
      if t == tag then
        table.remove(task.tags, i)
        break
      end
    end
  end

  -- Save the project
  local success, err = M.save_project(project)
  if not success then
    return false, err
  end

  return true, nil
end

-- Add tag to specific task
-- @param project: Project - The project to modify
-- @param task_id: string - Task ID
-- @param tag: string - Tag to add
-- @return boolean, string - success status and error message if failed
function M.tag_task(project, task_id, tag)
  local task = project.task_list[task_id]
  if not task then
    return false, "Task not found: " .. task_id
  end

  -- Check if task already has tag
  if vim.tbl_contains(task.tags, tag) then
    return true, nil  -- Already tagged, not an error
  end

  table.insert(task.tags, tag)

  -- Add tag to project if not exists
  if not vim.tbl_contains(project.tags, tag) then
    table.insert(project.tags, tag)
  end

  -- Save the project
  local success, err = M.save_project(project)
  if not success then
    return false, err
  end

  return true, nil
end

-- Remove tag from task
-- @param project: Project - The project to modify
-- @param task_id: string - Task ID
-- @param tag: string - Tag to remove
-- @return boolean, string - success status and error message if failed
function M.untag_task(project, task_id, tag)
  local task = project.task_list[task_id]
  if not task then
    return false, "Task not found: " .. task_id
  end

  -- Find and remove tag
  local found = false
  for i, t in ipairs(task.tags) do
    if t == tag then
      table.remove(task.tags, i)
      found = true
      break
    end
  end

  if not found then
    return false, "Tag not found on task: " .. tag
  end

  -- Save the project
  local success, err = M.save_project(project)
  if not success then
    return false, err
  end

  return true, nil
end

-- Find all tasks with given tag
-- @param project: Project - The project to search
-- @param tag: string - Tag to search for
-- @return table - Array of matching tasks
function M.search_by_tag(project, tag)
  local results = {}

  for _, task in pairs(project.task_list) do
    if vim.tbl_contains(task.tags, tag) then
      table.insert(results, task)
    end
  end

  return results
end

-- Find tasks matching multiple tags
-- @param project: Project - The project to search
-- @param tags: table - Array of tags to search for
-- @param match_all: boolean - If true, task must have all tags; if false, any tag
-- @return table - Array of matching tasks
function M.search_by_tags(project, tags, match_all)
  local results = {}

  for _, task in pairs(project.task_list) do
    local matches = 0
    for _, tag in ipairs(tags) do
      if vim.tbl_contains(task.tags, tag) then
        matches = matches + 1
      end
    end

    if match_all then
      if matches == #tags then
        table.insert(results, task)
      end
    else
      if matches > 0 then
        table.insert(results, task)
      end
    end
  end

  return results
end

return M
