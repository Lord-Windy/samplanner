-- Tree view UI for Samplanner
local operations = require('samplanner.domain.operations')
local buffers = require('samplanner.ui.buffers')

local M = {}

-- Tree state
M.state = {
  project = nil,
  buf = nil,
  win = nil,
  collapsed = {},  -- Set of collapsed node IDs
  cursor_node_id = nil,
}

-- Sort keys for consistent display
local function sorted_keys(t)
  local keys = {}
  for k in pairs(t) do
    table.insert(keys, k)
  end
  table.sort(keys, function(a, b)
    local a_parts = {}
    for part in a:gmatch("(%d+)") do
      table.insert(a_parts, tonumber(part))
    end
    local b_parts = {}
    for part in b:gmatch("(%d+)") do
      table.insert(b_parts, tonumber(part))
    end
    for i = 1, math.max(#a_parts, #b_parts) do
      local a_val = a_parts[i] or 0
      local b_val = b_parts[i] or 0
      if a_val ~= b_val then
        return a_val < b_val
      end
    end
    return false
  end)
  return keys
end

-- Check if a node has children
local function has_children(node)
  return node.subtasks and next(node.subtasks) ~= nil
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

      local line = string.format("%s%s [%s] %s: %s",
        indent, fold_marker, type_icon, id, name)

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
  table.insert(lines, "Keybindings: a=add child, A=add sibling, d=delete, r=rename")
  table.insert(lines, "             <CR>=open task, zo=expand, zc=collapse, zO=expand all, zC=collapse all")
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

  vim.ui.select({ "Area", "Component", "Job" }, {
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

  vim.ui.select({ "Area", "Component", "Job" }, {
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

-- Set up keybindings for tree buffer
local function setup_keymaps(buf)
  local opts = { buffer = buf, silent = true }

  vim.keymap.set('n', '<CR>', M.open_task, opts)
  vim.keymap.set('n', 'o', M.open_task, opts)
  vim.keymap.set('n', 'a', M.add_child, opts)
  vim.keymap.set('n', 'A', M.add_sibling, opts)
  vim.keymap.set('n', 'd', M.delete_node, opts)
  vim.keymap.set('n', 'r', M.rename_node, opts)
  vim.keymap.set('n', 'zo', M.expand, opts)
  vim.keymap.set('n', 'zc', M.collapse, opts)
  vim.keymap.set('n', 'zO', M.expand_all, opts)
  vim.keymap.set('n', 'zC', M.collapse_all, opts)
  vim.keymap.set('n', '<Tab>', M.toggle_collapse, opts)
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
