-- Task text format conversion
local models = require('samplanner.domain.models')

local M = {}

-- Convert Task to editable text format
-- @param task: Task - The task to convert
-- @return string - Human-readable text format
function M.task_to_text(task)
  local lines = {}

  -- Task header with ID
  table.insert(lines, string.format("── Task: %s ───────────────────", task.id or ""))
  table.insert(lines, "Name: " .. (task.name or ""))
  table.insert(lines, "")

  -- Details section
  table.insert(lines, "── Details ──────────────────────────")
  if task.details and task.details ~= "" then
    table.insert(lines, task.details)
  end
  table.insert(lines, "")

  -- Estimation section
  table.insert(lines, "── Estimation ───────────────────────")
  if task.estimation and task.estimation ~= "" then
    table.insert(lines, task.estimation)
  end
  table.insert(lines, "")

  -- Tags section
  table.insert(lines, "── Tags ─────────────────────────────")
  if task.tags and #task.tags > 0 then
    table.insert(lines, table.concat(task.tags, ", "))
  end

  return table.concat(lines, "\n")
end

-- Parse text back to Task
-- @param text: string - Human-readable text format
-- @return Task - Parsed task
function M.text_to_task(text)
  local id = ""
  local name = ""
  local details = ""
  local estimation = ""
  local tags = {}

  local current_section = nil
  local section_content = {}

  for line in text:gmatch("[^\r\n]*") do
    -- Check for task header
    local task_id = line:match("^── Task:%s*([^─]+)")
    if task_id then
      id = vim.trim(task_id)
      current_section = "header"
      section_content = {}
    elseif line:match("^── Details") then
      current_section = "details"
      section_content = {}
    elseif line:match("^── Estimation") then
      -- Save details before switching
      if current_section == "details" then
        details = table.concat(section_content, "\n")
      end
      current_section = "estimation"
      section_content = {}
    elseif line:match("^── Tags") then
      -- Save estimation before switching
      if current_section == "estimation" then
        estimation = table.concat(section_content, "\n")
      end
      current_section = "tags"
      section_content = {}
    elseif current_section == "header" then
      -- Parse name
      local name_val = line:match("^Name:%s*(.*)$")
      if name_val then
        name = vim.trim(name_val)
      end
    elseif current_section == "details" then
      if line ~= "" or #section_content > 0 then
        table.insert(section_content, line)
      end
    elseif current_section == "estimation" then
      if line ~= "" or #section_content > 0 then
        table.insert(section_content, line)
      end
    elseif current_section == "tags" then
      if line ~= "" then
        -- Parse comma-separated tags
        for tag in line:gmatch("[^,]+") do
          local trimmed = vim.trim(tag)
          if trimmed ~= "" then
            table.insert(tags, trimmed)
          end
        end
      end
    end
  end

  -- Handle final section
  if current_section == "details" then
    details = table.concat(section_content, "\n")
  elseif current_section == "estimation" then
    estimation = table.concat(section_content, "\n")
  end

  -- Trim trailing whitespace from multi-line content
  details = vim.trim(details)
  estimation = vim.trim(estimation)

  return models.Task.new(id, name, details, estimation, tags)
end

return M
