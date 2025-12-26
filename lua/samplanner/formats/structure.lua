-- Structure text format conversion
local models = require('samplanner.domain.models')

local M = {}

-- Sort keys for consistent display
local function sorted_keys(t)
  local keys = {}
  for k in pairs(t) do
    table.insert(keys, k)
  end
  table.sort(keys, function(a, b)
    -- Sort by comparing numeric segments
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

-- Render tree as indented text
-- @param structure: table - The structure tree (map of id -> StructureNode)
-- @param task_list: table - The task list for retrieving names (optional)
-- @return string - Indented text representation
function M.structure_to_text(structure, task_list)
  task_list = task_list or {}
  local lines = {}

  -- Recursive function to build display
  local function display_level(subtasks, depth)
    local keys = sorted_keys(subtasks)
    for _, id in ipairs(keys) do
      local node = subtasks[id]
      local indent = string.rep("  ", depth)
      local task = task_list[id]
      local name = task and task.name or ""

      local line = string.format("%s%s %s: %s", indent, id, node.type, name)
      table.insert(lines, line)

      if node.subtasks and next(node.subtasks) then
        display_level(node.subtasks, depth + 1)
      end
    end
  end

  display_level(structure, 0)

  return table.concat(lines, "\n")
end

-- Parse indented text back to structure
-- @param text: string - Indented text representation
-- @return table, table - structure tree and task_list
function M.text_to_structure(text)
  local structure = {}
  local task_list = {}

  -- Parse each line to extract: indent level, id, type, name
  local parsed_lines = {}

  for line in text:gmatch("[^\r\n]+") do
    -- Count leading spaces (2 spaces per indent level)
    local leading_spaces = line:match("^(%s*)")
    local indent_level = #leading_spaces / 2

    -- Parse the content: "1.2.3 Type: Name"
    local content = line:sub(#leading_spaces + 1)
    local id, node_type, name = content:match("^([%d%.]+)%s+(%w+):%s*(.*)$")

    if id and node_type then
      table.insert(parsed_lines, {
        indent = indent_level,
        id = id,
        type = node_type,
        name = vim.trim(name or "")
      })
    end
  end

  -- Build the tree structure
  -- We use the ID hierarchy to determine parent-child relationships
  for _, item in ipairs(parsed_lines) do
    local node = models.StructureNode.new(item.id, item.type, {})

    -- Create associated task if name is provided
    if item.name and item.name ~= "" then
      local task = models.Task.new(item.id, item.name, "", "", {})
      task_list[item.id] = task
    end

    -- Determine parent by ID structure (e.g., "1.2.3" has parent "1.2")
    local parent_id = item.id:match("^(.+)%.%d+$")

    if parent_id then
      -- Find parent node and add as child
      local function find_and_add(subtasks)
        if subtasks[parent_id] then
          subtasks[parent_id].subtasks[item.id] = node
          return true
        end
        for _, n in pairs(subtasks) do
          if n.subtasks and find_and_add(n.subtasks) then
            return true
          end
        end
        return false
      end

      if not find_and_add(structure) then
        -- Parent not found, add to root (shouldn't happen with valid input)
        structure[item.id] = node
      end
    else
      -- Top-level node
      structure[item.id] = node
    end
  end

  return structure, task_list
end

return M
