-- Buffer management for Samplanner
local operations = require('samplanner.domain.operations')
local task_format = require('samplanner.formats.task')
local session_format = require('samplanner.formats.session')
local structure_format = require('samplanner.formats.structure')

local M = {}

-- Track buffer state
M.buffers = {}

-- Buffer types
M.BUFFER_TYPES = {
  TASK = "task",
  SESSION = "session",
  STRUCTURE = "structure",
}

-- Get or create a scratch buffer with specific settings
-- @param name: string - Buffer name
-- @param filetype: string - Filetype for syntax highlighting
-- @return number - Buffer number
local function create_scratch_buffer(name, filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, name)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'acwrite')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'hide')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(buf, 'filetype', filetype)
  return buf
end

-- Open buffer in current window or split
-- @param buf: number - Buffer number
-- @param opts: table - Options {split?: "horizontal"|"vertical"|nil}
local function open_buffer(buf, opts)
  opts = opts or {}
  if opts.split == "horizontal" then
    vim.cmd('split')
  elseif opts.split == "vertical" then
    vim.cmd('vsplit')
  end
  vim.api.nvim_set_current_buf(buf)
end

-- Create a task buffer for editing
-- @param project: Project - The project
-- @param task_id: string - Task ID to edit
-- @param opts: table - Options {split?: string}
-- @return number|nil, string - Buffer number or nil, error message
function M.create_task_buffer(project, task_id, opts)
  local task = project.task_list[task_id]
  if not task then
    return nil, "Task not found: " .. task_id
  end

  local buf_name = string.format("samplanner://task/%s/%s",
    project.project_info.name, task_id)

  -- Check if buffer already exists
  local existing = vim.fn.bufnr(buf_name)
  if existing ~= -1 then
    open_buffer(existing, opts)
    return existing, nil
  end

  local buf = create_scratch_buffer(buf_name, "samplanner_task")
  local text = task_format.task_to_text(task)
  local lines = vim.split(text, "\n")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modified', false)

  -- Store buffer metadata
  M.buffers[buf] = {
    type = M.BUFFER_TYPES.TASK,
    project = project,
    task_id = task_id,
  }

  -- Set up save autocmd
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      M.save_task_buffer(buf)
    end,
  })

  -- Clean up on buffer delete
  vim.api.nvim_create_autocmd("BufDelete", {
    buffer = buf,
    callback = function()
      M.buffers[buf] = nil
    end,
  })

  open_buffer(buf, opts)
  return buf, nil
end

-- Save task buffer content
-- @param buf: number - Buffer number
-- @return boolean, string - Success and error message
function M.save_task_buffer(buf)
  local meta = M.buffers[buf]
  if not meta or meta.type ~= M.BUFFER_TYPES.TASK then
    return false, "Not a task buffer"
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local text = table.concat(lines, "\n")
  local parsed = task_format.text_to_task(text)

  -- Update the task
  local _, err = operations.update_task(meta.project, meta.task_id, {
    name = parsed.name,
    details = parsed.details,
    estimation = parsed.estimation,
    tags = parsed.tags,
  })

  if err then
    vim.notify("Failed to save task: " .. err, vim.log.levels.ERROR)
    return false, err
  end

  vim.api.nvim_buf_set_option(buf, 'modified', false)
  vim.notify("Task saved", vim.log.levels.INFO)
  return true, nil
end

-- Create a session buffer for editing
-- @param project: Project - The project
-- @param session_index: number - Session index (1-based)
-- @param opts: table - Options {split?: string}
-- @return number|nil, string - Buffer number or nil, error message
function M.create_session_buffer(project, session_index, opts)
  local session = project.time_log[session_index]
  if not session then
    return nil, "Session not found: " .. session_index
  end

  local buf_name = string.format("samplanner://session/%s/%d",
    project.project_info.name, session_index)

  -- Check if buffer already exists
  local existing = vim.fn.bufnr(buf_name)
  if existing ~= -1 then
    open_buffer(existing, opts)
    return existing, nil
  end

  local buf = create_scratch_buffer(buf_name, "samplanner_session")
  local text = session_format.session_to_text(session)
  local lines = vim.split(text, "\n")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modified', false)

  -- Store buffer metadata
  M.buffers[buf] = {
    type = M.BUFFER_TYPES.SESSION,
    project = project,
    session_index = session_index,
  }

  -- Set up save autocmd
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      M.save_session_buffer(buf)
    end,
  })

  -- Clean up on buffer delete
  vim.api.nvim_create_autocmd("BufDelete", {
    buffer = buf,
    callback = function()
      M.buffers[buf] = nil
    end,
  })

  open_buffer(buf, opts)
  return buf, nil
end

-- Save session buffer content
-- @param buf: number - Buffer number
-- @return boolean, string - Success and error message
function M.save_session_buffer(buf)
  local meta = M.buffers[buf]
  if not meta or meta.type ~= M.BUFFER_TYPES.SESSION then
    return false, "Not a session buffer"
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local text = table.concat(lines, "\n")
  local parsed = session_format.text_to_session(text)

  -- Update the session
  local _, err = operations.update_session(meta.project, meta.session_index, {
    notes = parsed.notes,
    interruptions = parsed.interruptions,
    interruption_minutes = parsed.interruption_minutes,
  })

  if err then
    vim.notify("Failed to save session: " .. err, vim.log.levels.ERROR)
    return false, err
  end

  vim.api.nvim_buf_set_option(buf, 'modified', false)
  vim.notify("Session saved", vim.log.levels.INFO)
  return true, nil
end

-- Create a structure buffer for editing
-- @param project: Project - The project
-- @param opts: table - Options {split?: string}
-- @return number|nil, string - Buffer number or nil, error message
function M.create_structure_buffer(project, opts)
  local buf_name = string.format("samplanner://structure/%s",
    project.project_info.name)

  -- Check if buffer already exists
  local existing = vim.fn.bufnr(buf_name)
  if existing ~= -1 then
    -- Refresh the content
    local text = structure_format.structure_to_text(project.structure, project.task_list)
    local lines = vim.split(text, "\n")
    vim.api.nvim_buf_set_lines(existing, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(existing, 'modified', false)
    open_buffer(existing, opts)
    return existing, nil
  end

  local buf = create_scratch_buffer(buf_name, "samplanner_structure")
  local text = structure_format.structure_to_text(project.structure, project.task_list)
  local lines = vim.split(text, "\n")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modified', false)

  -- Store buffer metadata
  M.buffers[buf] = {
    type = M.BUFFER_TYPES.STRUCTURE,
    project = project,
  }

  -- Set up save autocmd
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      M.save_structure_buffer(buf)
    end,
  })

  -- Clean up on buffer delete
  vim.api.nvim_create_autocmd("BufDelete", {
    buffer = buf,
    callback = function()
      M.buffers[buf] = nil
    end,
  })

  open_buffer(buf, opts)
  return buf, nil
end

-- Save structure buffer content
-- @param buf: number - Buffer number
-- @return boolean, string - Success and error message
function M.save_structure_buffer(buf)
  local meta = M.buffers[buf]
  if not meta or meta.type ~= M.BUFFER_TYPES.STRUCTURE then
    return false, "Not a structure buffer"
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local text = table.concat(lines, "\n")
  local new_structure, new_tasks = structure_format.text_to_structure(text)

  -- Update the project structure and tasks
  meta.project.structure = new_structure

  -- Merge task updates (preserve existing task details, just update names)
  for id, new_task in pairs(new_tasks) do
    local existing = meta.project.task_list[id]
    if existing then
      existing.name = new_task.name
    else
      meta.project.task_list[id] = new_task
    end
  end

  -- Save the project
  local success, err = operations.save_project(meta.project)
  if not success then
    vim.notify("Failed to save structure: " .. err, vim.log.levels.ERROR)
    return false, err
  end

  vim.api.nvim_buf_set_option(buf, 'modified', false)
  vim.notify("Structure saved", vim.log.levels.INFO)
  return true, nil
end

-- Refresh a buffer's content from the project
-- @param buf: number - Buffer number
function M.refresh_buffer(buf)
  local meta = M.buffers[buf]
  if not meta then
    return
  end

  if meta.type == M.BUFFER_TYPES.TASK then
    local task = meta.project.task_list[meta.task_id]
    if task then
      local text = task_format.task_to_text(task)
      local lines = vim.split(text, "\n")
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.api.nvim_buf_set_option(buf, 'modified', false)
    end
  elseif meta.type == M.BUFFER_TYPES.SESSION then
    local session = meta.project.time_log[meta.session_index]
    if session then
      local text = session_format.session_to_text(session)
      local lines = vim.split(text, "\n")
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.api.nvim_buf_set_option(buf, 'modified', false)
    end
  elseif meta.type == M.BUFFER_TYPES.STRUCTURE then
    local text = structure_format.structure_to_text(meta.project.structure, meta.project.task_list)
    local lines = vim.split(text, "\n")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, 'modified', false)
  end
end

-- Get buffer metadata
-- @param buf: number - Buffer number
-- @return table|nil - Buffer metadata
function M.get_buffer_meta(buf)
  return M.buffers[buf]
end

-- Close all samplanner buffers
function M.close_all()
  for buf, _ in pairs(M.buffers) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  M.buffers = {}
end

return M
