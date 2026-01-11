-- Tree view UI for Samplanner
local operations = require('samplanner.domain.operations')
local buffers = require('samplanner.ui.buffers')
local table_utils = require('samplanner.utils.table')

local M = {}

-- Local alias for sorted_keys
local sorted_keys = table_utils.sorted_keys

-- Tree state
M.state = {
  project = nil,
  buf = nil,
  win = nil,
  collapsed = {},  -- Set of collapsed node IDs
  cursor_node_id = nil,
  filters = {
    show_completed_jobs = false,     -- Default: hide completed jobs
    show_incomplete_jobs = true,     -- Default: show incomplete jobs
  },
}

-- Check if a node has children
local function has_children(node)
  return node.subtasks and next(node.subtasks) ~= nil
end

-- Check if a Job should be filtered based on completion status
-- @param node: StructureNode - The node to check
-- @param task: Task - The associated task (may be nil)
-- @return boolean - true if the node should be filtered (hidden)
local function should_filter_job(node, task)
  -- Only filter Jobs
  if node.type ~= "Job" then
    return false
  end

  -- Get completion status
  local is_completed = false
  if task and task.details and type(task.details) == "table" and task.details.completed ~= nil then
    is_completed = task.details.completed
  end

  -- Filter based on completion status and filter settings
  if is_completed and not M.state.filters.show_completed_jobs then
    return true  -- Hide completed jobs
  end
  if not is_completed and not M.state.filters.show_incomplete_jobs then
    return true  -- Hide incomplete jobs
  end

  return false
end

-- Build tree lines with metadata
-- @return table - Array of {line, node_id, depth, has_children, is_collapsed}
local function build_tree_lines(project)
  local result = {}

  local function build_level(subtasks, depth)
    local keys = sorted_keys(subtasks)
    for _, id in ipairs(keys) do
      local node = subtasks[id]
      local task = project.task_list[id]

      -- Check if this Job should be filtered
      if should_filter_job(node, task) then
        goto continue
      end

      local name = task and task.name or ""
      local has_kids = has_children(node)
      local is_collapsed = M.state.collapsed[id] or false

      -- Build indent and fold marker
      local indent = string.rep("  ", depth)
      local fold_marker = ""
      if has_kids then
        fold_marker = is_collapsed and "+" or "-"
      else
        fold_marker = " "
      end

      -- Type icons
      local type_icons = {
        Area = "A",
        Component = "C",
        Job = "J",
      }
      local type_icon = type_icons[node.type] or "?"

      -- Add completion indicator for Jobs
      local completion_indicator = ""
      if node.type == "Job" and task and task.details and type(task.details) == "table" and task.details.completed then
        completion_indicator = "[✓] "
      end

      local line = string.format("%s%s [%s] %s: %s%s",
        indent, fold_marker, type_icon, id, completion_indicator, name)

      table.insert(result, {
        line = line,
        node_id = id,
        depth = depth,
        has_children = has_kids,
        is_collapsed = is_collapsed,
      })

      -- Recurse if not collapsed
      if has_kids and not is_collapsed then
        build_level(node.subtasks, depth + 1)
      end

      ::continue::
    end
  end

  build_level(project.structure, 0)
  return result
end

-- Render the tree to the buffer
function M.render()
  if not M.state.buf or not vim.api.nvim_buf_is_valid(M.state.buf) then
    return
  end

  local tree_data = build_tree_lines(M.state.project)
  local lines = {}
  M.state.line_to_node = {}

  -- Header
  table.insert(lines, "# " .. M.state.project.project_info.name)
  table.insert(lines, "")

  -- Filter status
  local completed_status = M.state.filters.show_completed_jobs and "ON" or "OFF"
  local incomplete_status = M.state.filters.show_incomplete_jobs and "ON" or "OFF"
  table.insert(lines, string.format("Filters: Completed [%s]  Incomplete [%s]", completed_status, incomplete_status))
  table.insert(lines, "")

  table.insert(lines, "Keybindings: a=add child, A=add sibling, d=delete, r=rename")
  table.insert(lines, "             J=move down, K=move up, >=indent, <=outdent")
  table.insert(lines, "             <CR>=open task, zo=expand, zc=collapse, zO=expand all, zC=collapse all")
  table.insert(lines, "             tc=toggle completed, ti=toggle incomplete")
  table.insert(lines, "")

  local header_lines = #lines

  for i, data in ipairs(tree_data) do
    table.insert(lines, data.line)
    M.state.line_to_node[header_lines + i] = data
  end

  vim.api.nvim_buf_set_option(M.state.buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(M.state.buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.state.buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(M.state.buf, 'modified', false)
end

-- Get node ID at current cursor line
function M.get_node_at_cursor()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local data = M.state.line_to_node[line]
  return data and data.node_id or nil
end

-- Toggle collapse state
function M.toggle_collapse()
  local node_id = M.get_node_at_cursor()
  if not node_id then return end

  local data = M.state.line_to_node[vim.api.nvim_win_get_cursor(0)[1]]
  if not data or not data.has_children then return end

  M.state.collapsed[node_id] = not M.state.collapsed[node_id]
  M.render()
end

-- Expand node
function M.expand()
  local node_id = M.get_node_at_cursor()
  if not node_id then return end

  M.state.collapsed[node_id] = false
  M.render()
end

-- Collapse node
function M.collapse()
  local node_id = M.get_node_at_cursor()
  if not node_id then return end

  local data = M.state.line_to_node[vim.api.nvim_win_get_cursor(0)[1]]
  if data and data.has_children then
    M.state.collapsed[node_id] = true
  else
    -- If no children, collapse parent
    local parent_id = node_id:match("^(.+)%.%d+$")
    if parent_id then
      M.state.collapsed[parent_id] = true
    end
  end
  M.render()
end

-- Expand all nodes
function M.expand_all()
  M.state.collapsed = {}
  M.render()
end

-- Collapse all nodes
function M.collapse_all()
  local function collapse_level(subtasks)
    for id, node in pairs(subtasks) do
      if has_children(node) then
        M.state.collapsed[id] = true
        collapse_level(node.subtasks)
      end
    end
  end
  collapse_level(M.state.project.structure)
  M.render()
end

-- Open task details buffer
function M.open_task()
  local node_id = M.get_node_at_cursor()
  if not node_id then return end

  local task = M.state.project.task_list[node_id]
  if not task then
    vim.notify("No task associated with node: " .. node_id, vim.log.levels.WARN)
    return
  end

  buffers.create_task_buffer(M.state.project, node_id)
end

-- Add child node
function M.add_child()
  local parent_id = M.get_node_at_cursor()

  vim.ui.select({ "Area", "Component", "Job", "Freeform" }, {
    prompt = "Select node type:",
  }, function(node_type)
    if not node_type then return end

    vim.ui.input({ prompt = "Node name: " }, function(name)
      if not name or name == "" then return end

      local new_id, err = operations.add_node(M.state.project, parent_id, node_type, name)
      if err then
        vim.notify("Failed to add node: " .. err, vim.log.levels.ERROR)
        return
      end

      -- Expand parent if collapsed
      if parent_id then
        M.state.collapsed[parent_id] = false
      end

      vim.notify("Added node: " .. new_id, vim.log.levels.INFO)
      M.render()
    end)
  end)
end

-- Add sibling node
function M.add_sibling()
  local current_id = M.get_node_at_cursor()
  if not current_id then
    -- Add at root level
    M.add_child()
    return
  end

  -- Get parent ID
  local parent_id = current_id:match("^(.+)%.%d+$")

  vim.ui.select({ "Area", "Component", "Job", "Freeform" }, {
    prompt = "Select node type:",
  }, function(node_type)
    if not node_type then return end

    vim.ui.input({ prompt = "Node name: " }, function(name)
      if not name or name == "" then return end

      local new_id, err = operations.add_node(M.state.project, parent_id, node_type, name)
      if err then
        vim.notify("Failed to add node: " .. err, vim.log.levels.ERROR)
        return
      end

      vim.notify("Added node: " .. new_id, vim.log.levels.INFO)
      M.render()
    end)
  end)
end

-- Delete node
function M.delete_node()
  local node_id = M.get_node_at_cursor()
  if not node_id then return end

  vim.ui.input({
    prompt = string.format("Delete node '%s'? (y/n): ", node_id),
  }, function(confirm)
    if confirm ~= "y" and confirm ~= "Y" then return end

    local success, err = operations.remove_node(M.state.project, node_id)
    if not success then
      vim.notify("Failed to delete node: " .. err, vim.log.levels.ERROR)
      return
    end

    vim.notify("Deleted node: " .. node_id, vim.log.levels.INFO)
    M.render()
  end)
end

-- Rename node (update associated task name)
function M.rename_node()
  local node_id = M.get_node_at_cursor()
  if not node_id then return end

  local task = M.state.project.task_list[node_id]
  local current_name = task and task.name or ""

  vim.ui.input({
    prompt = "New name: ",
    default = current_name,
  }, function(new_name)
    if not new_name then return end

    if task then
      local _, err = operations.update_task(M.state.project, node_id, { name = new_name })
      if err then
        vim.notify("Failed to rename: " .. err, vim.log.levels.ERROR)
        return
      end
    else
      -- Create task if it doesn't exist
      local _, err = operations.create_task(M.state.project, node_id, new_name, "", "", {})
      if err then
        vim.notify("Failed to create task: " .. err, vim.log.levels.ERROR)
        return
      end
    end

    vim.notify("Renamed node: " .. node_id, vim.log.levels.INFO)
    M.render()
  end)
end

-- Move node down (swap with next sibling)
function M.move_down()
  local node_id = M.get_node_at_cursor()
  if not node_id then return end

  local success, err = operations.swap_siblings(M.state.project, node_id, "down")
  if not success then
    vim.notify(err, vim.log.levels.WARN)
    return
  end

  M.render()
  vim.notify("Moved node down: " .. node_id, vim.log.levels.INFO)
end

-- Move node up (swap with previous sibling)
function M.move_up()
  local node_id = M.get_node_at_cursor()
  if not node_id then return end

  local success, err = operations.swap_siblings(M.state.project, node_id, "up")
  if not success then
    vim.notify(err, vim.log.levels.WARN)
    return
  end

  M.render()
  vim.notify("Moved node up: " .. node_id, vim.log.levels.INFO)
end

-- Indent node (move under previous sibling)
function M.indent()
  local node_id = M.get_node_at_cursor()
  if not node_id then return end

  local success, err = operations.indent_node(M.state.project, node_id)
  if not success then
    vim.notify(err, vim.log.levels.WARN)
    return
  end

  M.render()
  vim.notify("Indented node: " .. node_id, vim.log.levels.INFO)
end

-- Outdent node (move to parent's level)
function M.outdent()
  local node_id = M.get_node_at_cursor()
  if not node_id then return end

  local success, err = operations.outdent_node(M.state.project, node_id)
  if not success then
    vim.notify(err, vim.log.levels.WARN)
    return
  end

  M.render()
  vim.notify("Outdented node: " .. node_id, vim.log.levels.INFO)
end

-- Toggle showing completed jobs
function M.toggle_completed_filter()
  M.state.filters.show_completed_jobs = not M.state.filters.show_completed_jobs
  local status = M.state.filters.show_completed_jobs and "shown" or "hidden"
  vim.notify("Completed jobs: " .. status, vim.log.levels.INFO)
  M.render()
end

-- Toggle showing incomplete jobs
function M.toggle_incomplete_filter()
  M.state.filters.show_incomplete_jobs = not M.state.filters.show_incomplete_jobs
  local status = M.state.filters.show_incomplete_jobs and "shown" or "hidden"
  vim.notify("Incomplete jobs: " .. status, vim.log.levels.INFO)
  M.render()
end

-- Set up keybindings for tree buffer
local function setup_keymaps(buf)
  local opts = { buffer = buf, silent = true }

  vim.keymap.set('n', '<CR>', M.open_task, opts)
  vim.keymap.set('n', 'o', M.open_task, opts)
  vim.keymap.set('n', 'a', M.add_child, opts)
  vim.keymap.set('n', 'A', M.add_sibling, opts)
  vim.keymap.set('n', 'd', M.delete_node, opts)
  vim.keymap.set('n', 'r', M.rename_node, opts)
  vim.keymap.set('n', 'J', M.move_down, opts)
  vim.keymap.set('n', 'K', M.move_up, opts)
  vim.keymap.set('n', '>', M.indent, opts)
  vim.keymap.set('n', '<', M.outdent, opts)
  vim.keymap.set('n', 'zo', M.expand, opts)
  vim.keymap.set('n', 'zc', M.collapse, opts)
  vim.keymap.set('n', 'zO', M.expand_all, opts)
  vim.keymap.set('n', 'zC', M.collapse_all, opts)
  vim.keymap.set('n', '<Tab>', M.toggle_collapse, opts)
  vim.keymap.set('n', 'tc', M.toggle_completed_filter, opts)
  vim.keymap.set('n', 'ti', M.toggle_incomplete_filter, opts)
  vim.keymap.set('n', 'R', M.refresh, opts)
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(0, true)
  end, opts)
end

-- Refresh tree from project
function M.refresh()
  -- Reload project from disk
  local project_name = M.state.project.project_info.name
  local project, err = operations.load_project(project_name)
  if err then
    vim.notify("Failed to reload project: " .. err, vim.log.levels.ERROR)
    return
  end
  M.state.project = project
  M.render()
end

-- Open tree view
-- @param project: Project - The project to display
-- @param opts: table - Options {split?: string, width?: number}
-- @return number, number - Buffer and window number
function M.open(project, opts)
  opts = opts or {}

  M.state.project = project
  M.state.collapsed = {}
  M.state.line_to_node = {}

  -- Create buffer
  local buf_name = "samplanner://tree/" .. project.project_info.name
  local existing = vim.fn.bufnr(buf_name)
  if existing ~= -1 and vim.api.nvim_buf_is_valid(existing) then
    M.state.buf = existing
  else
    M.state.buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(M.state.buf, buf_name)
    vim.api.nvim_buf_set_option(M.state.buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(M.state.buf, 'bufhidden', 'hide')
    vim.api.nvim_buf_set_option(M.state.buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(M.state.buf, 'filetype', 'samplanner_tree')
    setup_keymaps(M.state.buf)
  end

  -- Open window
  if opts.split == "vertical" then
    vim.cmd('vsplit')
    if opts.width then
      vim.cmd('vertical resize ' .. opts.width)
    end
  elseif opts.split == "horizontal" then
    vim.cmd('split')
  end

  vim.api.nvim_set_current_buf(M.state.buf)
  M.state.win = vim.api.nvim_get_current_win()

  -- Window options
  vim.api.nvim_win_set_option(M.state.win, 'number', false)
  vim.api.nvim_win_set_option(M.state.win, 'relativenumber', false)
  vim.api.nvim_win_set_option(M.state.win, 'wrap', false)
  vim.api.nvim_win_set_option(M.state.win, 'cursorline', true)

  M.render()
  return M.state.buf, M.state.win
end

-- Close tree view
function M.close()
  if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
    vim.api.nvim_win_close(M.state.win, true)
  end
  M.state.win = nil
end

-- Check if tree is open
function M.is_open()
  return M.state.win and vim.api.nvim_win_is_valid(M.state.win)
end

-- Toggle tree view
function M.toggle(project, opts)
  if M.is_open() then
    M.close()
  else
    M.open(project, opts)
  end
end

return M
