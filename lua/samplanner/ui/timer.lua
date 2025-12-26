-- Session timer UI for Samplanner
local operations = require('samplanner.domain.operations')
local buffers = require('samplanner.ui.buffers')

local M = {}

-- Timer state
M.state = {
  project = nil,
  session_index = nil,
  timer = nil,  -- uv timer handle
  start_time = nil,
  elapsed_seconds = 0,
}

-- Parse ISO timestamp to Unix timestamp
-- @param iso: string - ISO 8601 timestamp
-- @return number - Unix timestamp
local function parse_iso_timestamp(iso)
  if not iso or iso == "" then
    return 0
  end
  local year, month, day, hour, min, sec = iso:match("(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)")
  if year then
    return os.time({
      year = tonumber(year),
      month = tonumber(month),
      day = tonumber(day),
      hour = tonumber(hour),
      min = tonumber(min),
      sec = tonumber(sec),
    })
  end
  return 0
end

-- Format seconds to human-readable duration
-- @param seconds: number - Total seconds
-- @return string - Formatted duration (HH:MM:SS)
local function format_duration(seconds)
  local hours = math.floor(seconds / 3600)
  local mins = math.floor((seconds % 3600) / 60)
  local secs = seconds % 60
  return string.format("%02d:%02d:%02d", hours, mins, secs)
end

-- Update elapsed time from active session
local function update_elapsed()
  if not M.state.start_time then
    M.state.elapsed_seconds = 0
    return
  end
  M.state.elapsed_seconds = os.time() - M.state.start_time
end

-- Start timer update loop
local function start_timer_loop()
  if M.state.timer then
    return  -- Already running
  end

  local uv = vim.loop or vim.uv
  M.state.timer = uv.new_timer()
  M.state.timer:start(1000, 1000, vim.schedule_wrap(function()
    update_elapsed()
    -- Trigger statusline refresh
    vim.cmd('redrawstatus')
  end))
end

-- Stop timer update loop
local function stop_timer_loop()
  if M.state.timer then
    M.state.timer:stop()
    M.state.timer:close()
    M.state.timer = nil
  end
end

-- Start a new session
-- @param project: Project - The project
-- @return number|nil, string - Session index or nil, error message
function M.start(project)
  -- Check if already has active session
  local active_index, _ = operations.get_active_session(project)
  if active_index then
    vim.notify("Session already active", vim.log.levels.WARN)
    return active_index, nil
  end

  local session_index, err = operations.start_session(project)
  if err then
    vim.notify("Failed to start session: " .. err, vim.log.levels.ERROR)
    return nil, err
  end

  M.state.project = project
  M.state.session_index = session_index
  M.state.start_time = os.time()
  M.state.elapsed_seconds = 0

  start_timer_loop()

  vim.notify("Session started", vim.log.levels.INFO)
  return session_index, nil
end

-- Stop the current session
-- @param project: Project - The project (optional, uses state if nil)
-- @return boolean, string - Success and error message
function M.stop(project)
  project = project or M.state.project
  if not project then
    return false, "No project specified"
  end

  local active_index, _ = operations.get_active_session(project)
  if not active_index then
    vim.notify("No active session", vim.log.levels.WARN)
    return false, "No active session"
  end

  local success, err = operations.stop_session(project, active_index)
  if not success then
    vim.notify("Failed to stop session: " .. err, vim.log.levels.ERROR)
    return false, err
  end

  stop_timer_loop()

  local duration = format_duration(M.state.elapsed_seconds)
  vim.notify("Session stopped. Duration: " .. duration, vim.log.levels.INFO)

  -- Reset state
  M.state.session_index = nil
  M.state.start_time = nil
  M.state.elapsed_seconds = 0

  return true, nil
end

-- Open current session in buffer
-- @param project: Project - The project (optional, uses state if nil)
-- @param opts: table - Buffer options
function M.open_session(project, opts)
  project = project or M.state.project
  if not project then
    vim.notify("No project loaded", vim.log.levels.ERROR)
    return
  end

  local active_index, _ = operations.get_active_session(project)
  if not active_index then
    vim.notify("No active session", vim.log.levels.WARN)
    return
  end

  buffers.create_session_buffer(project, active_index, opts)
end

-- Open session by index
-- @param project: Project - The project
-- @param session_index: number - Session index (optional, opens picker if nil)
-- @param opts: table - Buffer options
function M.open_session_by_index(project, session_index, opts)
  if session_index then
    buffers.create_session_buffer(project, session_index, opts)
    return
  end

  -- Show session picker
  local sessions = project.time_log or {}
  if #sessions == 0 then
    vim.notify("No sessions in project", vim.log.levels.WARN)
    return
  end

  local items = {}
  for i, session in ipairs(sessions) do
    local start_display = session.start_timestamp:gsub("T", " "):gsub("Z", ""):sub(1, 16)
    local end_display = session.end_timestamp ~= ""
      and session.end_timestamp:gsub("T", " "):gsub("Z", ""):sub(1, 16)
      or "(active)"
    local duration = ""
    if session.end_timestamp ~= "" then
      local start_ts = parse_iso_timestamp(session.start_timestamp)
      local end_ts = parse_iso_timestamp(session.end_timestamp)
      duration = format_duration(end_ts - start_ts)
    end
    table.insert(items, {
      index = i,
      session = session,
      display = string.format("#%d: %s to %s %s", i, start_display, end_display, duration),
    })
  end

  vim.ui.select(items, {
    prompt = "Select session:",
    format_item = function(item)
      return item.display
    end,
  }, function(choice)
    if choice then
      buffers.create_session_buffer(project, choice.index, opts)
    end
  end)
end

-- Add task to current session
-- @param project: Project - The project
-- @param task_id: string - Task ID (optional, opens picker if nil)
function M.add_task_to_session(project, task_id)
  local active_index, _ = operations.get_active_session(project)
  if not active_index then
    vim.notify("No active session", vim.log.levels.WARN)
    return
  end

  if task_id then
    local success, err = operations.add_task_to_session(project, active_index, task_id)
    if not success then
      vim.notify("Failed to add task: " .. err, vim.log.levels.ERROR)
    else
      vim.notify("Added task to session: " .. task_id, vim.log.levels.INFO)
    end
    return
  end

  -- Show task picker
  local tasks = {}
  for id, task in pairs(project.task_list) do
    table.insert(tasks, { id = id, task = task })
  end

  -- Sort by ID
  table.sort(tasks, function(a, b)
    return a.id < b.id
  end)

  vim.ui.select(tasks, {
    prompt = "Add task to session:",
    format_item = function(item)
      return string.format("[%s] %s", item.id, item.task.name)
    end,
  }, function(choice)
    if choice then
      local success, err = operations.add_task_to_session(project, active_index, choice.id)
      if not success then
        vim.notify("Failed to add task: " .. err, vim.log.levels.ERROR)
      else
        vim.notify("Added task to session: " .. choice.id, vim.log.levels.INFO)
      end
    end
  end)
end

-- Get elapsed time for statusline
-- @return string - Formatted elapsed time or empty string if no active session
function M.get_statusline()
  if not M.state.start_time then
    return ""
  end
  update_elapsed()
  return format_duration(M.state.elapsed_seconds)
end

-- Get statusline component with icon
-- @return string - Statusline string
function M.get_statusline_component()
  local elapsed = M.get_statusline()
  if elapsed == "" then
    return ""
  end
  return string.format("[SP %s]", elapsed)
end

-- Check if session is active
-- @return boolean
function M.is_active()
  return M.state.start_time ~= nil
end

-- Initialize timer state from project (for when project is loaded)
-- @param project: Project - The project
function M.sync_with_project(project)
  local active_index, session = operations.get_active_session(project)

  if active_index and session then
    M.state.project = project
    M.state.session_index = active_index
    M.state.start_time = parse_iso_timestamp(session.start_timestamp)
    update_elapsed()
    start_timer_loop()
  else
    stop_timer_loop()
    M.state.project = nil
    M.state.session_index = nil
    M.state.start_time = nil
    M.state.elapsed_seconds = 0
  end
end

-- Clean up timer on plugin unload
function M.cleanup()
  stop_timer_loop()
end

-- Quick session menu
-- @param project: Project - The project
function M.show_menu(project)
  local items = {}

  local active_index, _ = operations.get_active_session(project)
  if active_index then
    table.insert(items, { action = "stop", display = "Stop current session" })
    table.insert(items, { action = "open", display = "Edit current session" })
    table.insert(items, { action = "add_task", display = "Add task to session" })
  else
    table.insert(items, { action = "start", display = "Start new session" })
  end

  table.insert(items, { action = "list", display = "View all sessions" })

  vim.ui.select(items, {
    prompt = "Session menu:",
    format_item = function(item)
      return item.display
    end,
  }, function(choice)
    if not choice then return end

    if choice.action == "start" then
      M.start(project)
    elseif choice.action == "stop" then
      M.stop(project)
    elseif choice.action == "open" then
      M.open_session(project, { split = "vertical" })
    elseif choice.action == "add_task" then
      M.add_task_to_session(project)
    elseif choice.action == "list" then
      M.open_session_by_index(project, nil, { split = "vertical" })
    end
  end)
end

return M
