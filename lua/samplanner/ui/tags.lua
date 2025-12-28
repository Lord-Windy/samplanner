-- Tag management UI for Samplanner
local operations = require('samplanner.domain.operations')

local M = {}

-- Open tag picker with fuzzy selection
-- Uses vim.ui.select for basic picker (can be enhanced with telescope)
-- @param project: Project - The project
-- @param callback: function - Called with selected tag(s)
-- @param opts: table - Options {multi?: boolean, prompt?: string}
function M.open_tag_picker(project, callback, opts)
  opts = opts or {}
  local tags = project.tags or {}

  if #tags == 0 then
    vim.notify("No tags in project", vim.log.levels.WARN)
    callback(nil)
    return
  end

  if opts.multi then
    -- Multi-select mode
    M.open_multi_tag_picker(project, callback, opts)
  else
    -- Single select mode
    vim.ui.select(tags, {
      prompt = opts.prompt or "Select tag:",
      format_item = function(tag)
        -- Show task count for each tag
        local count = #operations.search_by_tag(project, tag)
        return string.format("%s (%d tasks)", tag, count)
      end,
    }, function(selected)
      callback(selected)
    end)
  end
end

-- Multi-tag picker implementation
-- @param project: Project - The project
-- @param callback: function - Called with array of selected tags
-- @param opts: table - Options
function M.open_multi_tag_picker(project, callback, opts)
  opts = opts or {}
  local tags = project.tags or {}
  local selected = {}

  local function show_picker()
    local items = {}
    for _, tag in ipairs(tags) do
      local prefix = selected[tag] and "[x]" or "[ ]"
      local count = #operations.search_by_tag(project, tag)
      table.insert(items, {
        tag = tag,
        display = string.format("%s %s (%d tasks)", prefix, tag, count),
      })
    end
    table.insert(items, { tag = "__done__", display = "-- Done --" })

    vim.ui.select(items, {
      prompt = opts.prompt or "Select tags (multi):",
      format_item = function(item)
        return item.display
      end,
    }, function(choice)
      if not choice or choice.tag == "__done__" then
        -- Return selected tags as array
        local result = {}
        for tag, _ in pairs(selected) do
          table.insert(result, tag)
        end
        callback(#result > 0 and result or nil)
        return
      end

      -- Toggle selection
      selected[choice.tag] = not selected[choice.tag]
      -- Show picker again
      show_picker()
    end)
  end

  show_picker()
end

-- Prompt to add tag to task
-- @param project: Project - The project
-- @param task_id: string - Task ID
-- @param callback: function - Called after tagging (optional)
function M.add_tag_prompt(project, task_id, callback)
  local task = project.task_list[task_id]
  if not task then
    vim.notify("Task not found: " .. task_id, vim.log.levels.ERROR)
    return
  end

  local existing_tags = project.tags or {}
  local items = {}

  -- Add option to create new tag
  table.insert(items, { type = "new", display = "+ Create new tag" })

  -- Add existing tags (excluding already assigned ones)
  for _, tag in ipairs(existing_tags) do
    if not vim.tbl_contains(task.tags, tag) then
      table.insert(items, { type = "existing", tag = tag, display = tag })
    end
  end

  if #items == 1 then
    -- Only "create new" option, go straight to input
    M.create_new_tag_prompt(project, task_id, callback)
    return
  end

  vim.ui.select(items, {
    prompt = "Add tag to task:",
    format_item = function(item)
      return item.display
    end,
  }, function(choice)
    if not choice then return end

    if choice.type == "new" then
      M.create_new_tag_prompt(project, task_id, callback)
    else
      local success, err = operations.tag_task(project, task_id, choice.tag)
      if not success then
        vim.notify("Failed to add tag: " .. err, vim.log.levels.ERROR)
      else
        vim.notify("Added tag: " .. choice.tag, vim.log.levels.INFO)
      end
      if callback then callback() end
    end
  end)
end

-- Prompt to create and add new tag
-- @param project: Project - The project
-- @param task_id: string|nil - Task ID (optional, if nil just creates project tag)
-- @param callback: function - Called after creation (optional)
function M.create_new_tag_prompt(project, task_id, callback)
  vim.ui.input({ prompt = "New tag name: " }, function(tag)
    if not tag or tag == "" then return end

    local success, err

    if task_id then
      success, err = operations.tag_task(project, task_id, tag)
    else
      success, err = operations.add_tag(project, tag)
    end

    if not success then
      vim.notify("Failed to create tag: " .. err, vim.log.levels.ERROR)
    else
      vim.notify("Created tag: " .. tag, vim.log.levels.INFO)
    end

    if callback then callback() end
  end)
end

-- Remove tag from task
-- @param project: Project - The project
-- @param task_id: string - Task ID
-- @param callback: function - Called after removal (optional)
function M.remove_tag_prompt(project, task_id, callback)
  local task = project.task_list[task_id]
  if not task then
    vim.notify("Task not found: " .. task_id, vim.log.levels.ERROR)
    return
  end

  if #task.tags == 0 then
    vim.notify("Task has no tags", vim.log.levels.WARN)
    return
  end

  vim.ui.select(task.tags, {
    prompt = "Remove tag from task:",
  }, function(tag)
    if not tag then return end

    local success, err = operations.untag_task(project, task_id, tag)
    if not success then
      vim.notify("Failed to remove tag: " .. err, vim.log.levels.ERROR)
    else
      vim.notify("Removed tag: " .. tag, vim.log.levels.INFO)
    end

    if callback then callback() end
  end)
end

-- Show tag search UI - filter tasks by tags
-- @param project: Project - The project
-- @param opts: table - Options {match_all?: boolean}
function M.show_tag_search(project, opts)
  opts = opts or {}

  M.open_tag_picker(project, function(tags)
    if not tags then return end

    local tasks
    if type(tags) == "table" then
      tasks = operations.search_by_tags(project, tags, opts.match_all or false)
    else
      tasks = operations.search_by_tag(project, tags)
    end

    if #tasks == 0 then
      vim.notify("No tasks found with selected tags", vim.log.levels.INFO)
      return
    end

    -- Show results in a picker
    vim.ui.select(tasks, {
      prompt = string.format("Tasks with tag(s) (%d found):", #tasks),
      format_item = function(task)
        local tag_str = table.concat(task.tags or {}, ", ")
        return string.format("[%s] %s (%s)", task.id, task.name, tag_str)
      end,
    }, function(selected)
      if not selected then return end

      -- Open selected task
      local buffers = require('samplanner.ui.buffers')
      buffers.create_task_buffer(project, selected.id)
    end)
  end, { multi = opts.multi, prompt = "Search by tag:" })
end

-- Show all tags with task counts
-- @param project: Project - The project
function M.show_tag_overview(project)
  local tags = project.tags or {}

  if #tags == 0 then
    vim.notify("No tags in project", vim.log.levels.INFO)
    return
  end

  local items = {}
  for _, tag in ipairs(tags) do
    local count = #operations.search_by_tag(project, tag)
    table.insert(items, {
      tag = tag,
      count = count,
      display = string.format("%s: %d task(s)", tag, count),
    })
  end

  -- Sort by count descending
  table.sort(items, function(a, b)
    return a.count > b.count
  end)

  vim.ui.select(items, {
    prompt = "Tags overview:",
    format_item = function(item)
      return item.display
    end,
  }, function(choice)
    if not choice then return end

    -- Show tasks with this tag
    local tasks = operations.search_by_tag(project, choice.tag)

    vim.ui.select(tasks, {
      prompt = string.format("Tasks with '%s':", choice.tag),
      format_item = function(task)
        return string.format("[%s] %s", task.id, task.name)
      end,
    }, function(selected)
      if not selected then return end

      -- Open selected task
      local buffers = require('samplanner.ui.buffers')
      buffers.create_task_buffer(project, selected.id)
    end)
  end)
end

-- Manage project tags (add/remove)
-- @param project: Project - The project
function M.manage_tags(project)
  local items = {
    { action = "add", display = "+ Add new tag" },
    { action = "remove", display = "- Remove tag" },
    { action = "overview", display = "View tag overview" },
    { action = "search", display = "Search by tag" },
    { action = "multi_search", display = "Search by multiple tags" },
  }

  vim.ui.select(items, {
    prompt = "Tag management:",
    format_item = function(item)
      return item.display
    end,
  }, function(choice)
    if not choice then return end

    if choice.action == "add" then
      M.create_new_tag_prompt(project, nil, function()
        M.manage_tags(project)  -- Return to menu
      end)
    elseif choice.action == "remove" then
      if #(project.tags or {}) == 0 then
        vim.notify("No tags to remove", vim.log.levels.WARN)
        return
      end

      vim.ui.select(project.tags, {
        prompt = "Select tag to remove:",
      }, function(tag)
        if not tag then return end

        vim.ui.input({
          prompt = string.format("Remove '%s' from all tasks? (y/n): ", tag),
        }, function(confirm)
          if confirm ~= "y" and confirm ~= "Y" then return end

          local success, err = operations.remove_tag(project, tag)
          if not success then
            vim.notify("Failed to remove tag: " .. err, vim.log.levels.ERROR)
          else
            vim.notify("Removed tag: " .. tag, vim.log.levels.INFO)
          end
        end)
      end)
    elseif choice.action == "overview" then
      M.show_tag_overview(project)
    elseif choice.action == "search" then
      M.show_tag_search(project, { multi = false })
    elseif choice.action == "multi_search" then
      M.show_tag_search(project, { multi = true, match_all = false })
    end
  end)
end

-- Integration with telescope.nvim if available
-- @param project: Project - The project
-- @param callback: function - Called with selected tag
function M.telescope_tag_picker(project, callback)
  local has_telescope, telescope = pcall(require, 'telescope')
  if not has_telescope then
    -- Fall back to vim.ui.select
    M.open_tag_picker(project, callback)
    return
  end

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  local tags = project.tags or {}
  local entries = {}

  for _, tag in ipairs(tags) do
    local count = #operations.search_by_tag(project, tag)
    table.insert(entries, {
      tag = tag,
      count = count,
      display = string.format("%s (%d)", tag, count),
    })
  end

  pickers.new({}, {
    prompt_title = "Select Tag",
    finder = finders.new_table({
      results = entries,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.display,
          ordinal = entry.tag,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          callback(selection.value.tag)
        end
      end)
      return true
    end,
  }):find()
end

return M
