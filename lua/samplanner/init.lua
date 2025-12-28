local M = {}

local defaults = {
  filepath = "/home/sam/Dropbox/planning",
}

-- Plugin state
M.state = {
  project = nil,  -- Currently loaded project
}

-- Get storage directory
local function get_storage_dir()
  return M.config and M.config.filepath or defaults.filepath
end

--------------------------------------------------------------------------------
-- Core Commands
--------------------------------------------------------------------------------

-- Open project picker or current project
function M.open_picker()
  local file_storage = require('samplanner.ports.file_storage')
  local operations = require('samplanner.domain.operations')
  local tree = require('samplanner.ui.tree')

  -- If project is loaded, open tree view
  if M.state.project then
    tree.open(M.state.project, { split = "vertical", width = 50 })
    return
  end

  -- Otherwise show project picker
  local projects = file_storage.list_projects(get_storage_dir())

  if #projects == 0 then
    vim.notify("No projects found. Use :SamplannerNew <name> to create one.", vim.log.levels.INFO)
    return
  end

  vim.ui.select(projects, {
    prompt = "Select project:",
  }, function(choice)
    if not choice then return end

    local project, err = operations.load_project(choice)
    if err then
      vim.notify("Failed to load project: " .. err, vim.log.levels.ERROR)
      return
    end

    M.state.project = project

    -- Sync timer with project
    local timer = require('samplanner.ui.timer')
    timer.sync_with_project(project)

    vim.notify("Loaded project: " .. choice, vim.log.levels.INFO)
    tree.open(project, { split = "vertical", width = 50 })
  end)
end

-- Create new project
-- @param name: string - Project name
function M.create_project(name)
  if not name or name == "" then
    vim.ui.input({ prompt = "Project name: " }, function(input)
      if input and input ~= "" then
        M.create_project(input)
      end
    end)
    return
  end

  local operations = require('samplanner.domain.operations')
  local tree = require('samplanner.ui.tree')

  -- Generate ID from name (lowercase, underscores)
  local id = name:lower():gsub("%s+", "_"):gsub("[^%w_]", "")

  local project, err = operations.create_project(id, name)
  if err then
    vim.notify("Failed to create project: " .. err, vim.log.levels.ERROR)
    return
  end

  M.state.project = project
  vim.notify("Created project: " .. name, vim.log.levels.INFO)
  tree.open(project, { split = "vertical", width = 50 })
end

-- Load existing project
-- @param name: string - Project name
function M.load_project(name)
  local file_storage = require('samplanner.ports.file_storage')
  local operations = require('samplanner.domain.operations')
  local tree = require('samplanner.ui.tree')
  local timer = require('samplanner.ui.timer')

  if not name or name == "" then
    -- Show picker
    local projects = file_storage.list_projects(get_storage_dir())

    if #projects == 0 then
      vim.notify("No projects found.", vim.log.levels.WARN)
      return
    end

    vim.ui.select(projects, {
      prompt = "Load project:",
    }, function(choice)
      if choice then
        M.load_project(choice)
      end
    end)
    return
  end

  local project, err = operations.load_project(name)
  if err then
    vim.notify("Failed to load project: " .. err, vim.log.levels.ERROR)
    return
  end

  M.state.project = project
  timer.sync_with_project(project)
  vim.notify("Loaded project: " .. name, vim.log.levels.INFO)
  tree.open(project, { split = "vertical", width = 50 })
end

-- Open tree structure view
function M.open_tree()
  if not M.state.project then
    vim.notify("No project loaded. Use :SamplannerLoad first.", vim.log.levels.WARN)
    return
  end

  local tree = require('samplanner.ui.tree')
  tree.open(M.state.project, { split = "vertical", width = 50 })
end

-- Open task by ID
-- @param task_id: string - Task ID
function M.open_task(task_id)
  if not M.state.project then
    vim.notify("No project loaded. Use :SamplannerLoad first.", vim.log.levels.WARN)
    return
  end

  local buffers = require('samplanner.ui.buffers')

  if not task_id or task_id == "" then
    -- Show task picker
    local tasks = {}
    for id, task in pairs(M.state.project.task_list) do
      table.insert(tasks, { id = id, task = task })
    end

    if #tasks == 0 then
      vim.notify("No tasks in project.", vim.log.levels.WARN)
      return
    end

    -- Sort by ID
    table.sort(tasks, function(a, b)
      return a.id < b.id
    end)

    vim.ui.select(tasks, {
      prompt = "Select task:",
      format_item = function(item)
        return string.format("[%s] %s", item.id, item.task.name)
      end,
    }, function(choice)
      if choice then
        buffers.create_task_buffer(M.state.project, choice.id, { split = "vertical" })
      end
    end)
    return
  end

  local _, err = buffers.create_task_buffer(M.state.project, task_id, { split = "vertical" })
  if err then
    vim.notify(err, vim.log.levels.ERROR)
  end
end

-- Open tag management
function M.open_tags()
  if not M.state.project then
    vim.notify("No project loaded. Use :SamplannerLoad first.", vim.log.levels.WARN)
    return
  end

  local tags = require('samplanner.ui.tags')
  tags.manage_tags(M.state.project)
end

--------------------------------------------------------------------------------
-- Session Commands
--------------------------------------------------------------------------------

-- Start time tracking session
function M.start_session()
  if not M.state.project then
    vim.notify("No project loaded. Use :SamplannerLoad first.", vim.log.levels.WARN)
    return
  end

  local timer = require('samplanner.ui.timer')
  timer.start(M.state.project)
end

-- Stop current session
function M.stop_session()
  if not M.state.project then
    vim.notify("No project loaded. Use :SamplannerLoad first.", vim.log.levels.WARN)
    return
  end

  local timer = require('samplanner.ui.timer')
  timer.stop(M.state.project)
end

-- Open session buffer
-- @param index: number|nil - Session index (nil for current active or picker)
function M.open_session(index)
  if not M.state.project then
    vim.notify("No project loaded. Use :SamplannerLoad first.", vim.log.levels.WARN)
    return
  end

  local timer = require('samplanner.ui.timer')

  if index then
    timer.open_session_by_index(M.state.project, tonumber(index), { split = "vertical" })
  else
    -- Try to open active session, otherwise show picker
    local operations = require('samplanner.domain.operations')
    local active_index, _ = operations.get_active_session(M.state.project)

    if active_index then
      timer.open_session(M.state.project, { split = "vertical" })
    else
      timer.open_session_by_index(M.state.project, nil, { split = "vertical" })
    end
  end
end

-- List all sessions
function M.list_sessions()
  if not M.state.project then
    vim.notify("No project loaded. Use :SamplannerLoad first.", vim.log.levels.WARN)
    return
  end

  local timer = require('samplanner.ui.timer')
  timer.open_session_by_index(M.state.project, nil, { split = "vertical" })
end

--------------------------------------------------------------------------------
-- Search Commands
--------------------------------------------------------------------------------

-- Search tasks by text
-- @param query: string - Search query
function M.search_tasks(query)
  if not M.state.project then
    vim.notify("No project loaded. Use :SamplannerLoad first.", vim.log.levels.WARN)
    return
  end

  if not query or query == "" then
    vim.ui.input({ prompt = "Search tasks: " }, function(input)
      if input and input ~= "" then
        M.search_tasks(input)
      end
    end)
    return
  end

  local buffers = require('samplanner.ui.buffers')
  local results = {}
  local query_lower = query:lower()

  -- Search in task names, details, and IDs
  for id, task in pairs(M.state.project.task_list) do
    local matches = false

    if id:lower():find(query_lower, 1, true) then
      matches = true
    elseif task.name:lower():find(query_lower, 1, true) then
      matches = true
    elseif task.details:lower():find(query_lower, 1, true) then
      matches = true
    end

    if matches then
      table.insert(results, { id = id, task = task })
    end
  end

  if #results == 0 then
    vim.notify("No tasks found matching: " .. query, vim.log.levels.INFO)
    return
  end

  -- Sort by ID
  table.sort(results, function(a, b)
    return a.id < b.id
  end)

  vim.ui.select(results, {
    prompt = string.format("Search results for '%s' (%d found):", query, #results),
    format_item = function(item)
      return string.format("[%s] %s", item.id, item.task.name)
    end,
  }, function(choice)
    if choice then
      buffers.create_task_buffer(M.state.project, choice.id, { split = "vertical" })
    end
  end)
end

-- Filter tasks by tag
-- @param tag: string - Tag to filter by
function M.search_by_tag(tag)
  if not M.state.project then
    vim.notify("No project loaded. Use :SamplannerLoad first.", vim.log.levels.WARN)
    return
  end

  local tags_ui = require('samplanner.ui.tags')

  if not tag or tag == "" then
    tags_ui.show_tag_search(M.state.project, { multi = false })
    return
  end

  local operations = require('samplanner.domain.operations')
  local buffers = require('samplanner.ui.buffers')
  local results = operations.search_by_tag(M.state.project, tag)

  if #results == 0 then
    vim.notify("No tasks found with tag: " .. tag, vim.log.levels.INFO)
    return
  end

  vim.ui.select(results, {
    prompt = string.format("Tasks with tag '%s' (%d found):", tag, #results),
    format_item = function(task)
      return string.format("[%s] %s", task.id, task.name)
    end,
  }, function(choice)
    if choice then
      buffers.create_task_buffer(M.state.project, choice.id, { split = "vertical" })
    end
  end)
end

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

-- Get current project (for external access)
function M.get_project()
  return M.state.project
end

-- Reload current project from disk
function M.reload_project()
  if not M.state.project then
    vim.notify("No project loaded.", vim.log.levels.WARN)
    return
  end

  local operations = require('samplanner.domain.operations')
  local timer = require('samplanner.ui.timer')
  local name = M.state.project.project_info.name

  local project, err = operations.load_project(name)
  if err then
    vim.notify("Failed to reload project: " .. err, vim.log.levels.ERROR)
    return
  end

  M.state.project = project
  timer.sync_with_project(project)
  vim.notify("Reloaded project: " .. name, vim.log.levels.INFO)
end

--------------------------------------------------------------------------------
-- Command Registration
--------------------------------------------------------------------------------

local function register_commands()
  -- Core commands
  vim.api.nvim_create_user_command('Samplanner', function()
    M.open_picker()
  end, { desc = "Open Samplanner project picker or current project" })

  vim.api.nvim_create_user_command('SamplannerNew', function(opts)
    M.create_project(opts.args)
  end, { nargs = "?", desc = "Create new Samplanner project" })

  vim.api.nvim_create_user_command('SamplannerLoad', function(opts)
    M.load_project(opts.args)
  end, {
    nargs = "?",
    desc = "Load Samplanner project",
    complete = function()
      local file_storage = require('samplanner.ports.file_storage')
      return file_storage.list_projects(get_storage_dir())
    end,
  })

  vim.api.nvim_create_user_command('SamplannerTree', function()
    M.open_tree()
  end, { desc = "Open tree structure view" })

  vim.api.nvim_create_user_command('SamplannerTask', function(opts)
    M.open_task(opts.args)
  end, {
    nargs = "?",
    desc = "Open task by ID",
    complete = function()
      if not M.state.project then return {} end
      local ids = {}
      for id in pairs(M.state.project.task_list) do
        table.insert(ids, id)
      end
      table.sort(ids)
      return ids
    end,
  })

  vim.api.nvim_create_user_command('SamplannerTags', function()
    M.open_tags()
  end, { desc = "Open tag management" })

  -- Session commands
  vim.api.nvim_create_user_command('SamplannerStart', function()
    M.start_session()
  end, { desc = "Start time tracking session" })

  vim.api.nvim_create_user_command('SamplannerStop', function()
    M.stop_session()
  end, { desc = "Stop current session" })

  vim.api.nvim_create_user_command('SamplannerSession', function(opts)
    local index = opts.args ~= "" and opts.args or nil
    M.open_session(index)
  end, { nargs = "?", desc = "Open session buffer" })

  vim.api.nvim_create_user_command('SamplannerSessions', function()
    M.list_sessions()
  end, { desc = "List all sessions" })

  -- Search commands
  vim.api.nvim_create_user_command('SamplannerSearch', function(opts)
    M.search_tasks(opts.args)
  end, { nargs = "?", desc = "Search tasks by text" })

  vim.api.nvim_create_user_command('SamplannerByTag', function(opts)
    M.search_by_tag(opts.args)
  end, {
    nargs = "?",
    desc = "Filter tasks by tag",
    complete = function()
      if not M.state.project then return {} end
      return M.state.project.tags or {}
    end,
  })

  -- Utility commands
  vim.api.nvim_create_user_command('SamplannerReload', function()
    M.reload_project()
  end, { desc = "Reload current project from disk" })
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", {}, defaults, opts or {})

  -- Register commands
  register_commands()
end

return M
