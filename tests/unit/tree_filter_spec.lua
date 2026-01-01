-- Unit tests for tree view filtering
-- Run with: luajit tests/unit/tree_filter_spec.lua

-- Add the lua directory to the package path
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua;./tests/helpers/?.lua"

-- Load mini test framework
require('mini_test')

-- Mock vim global for testing outside Neovim
_G.vim = {
  trim = function(s)
    return s:match("^%s*(.-)%s*$")
  end,
  inspect = function(t)
    if type(t) ~= "table" then
      return tostring(t)
    end
    local items = {}
    for k, v in pairs(t) do
      if type(v) == "table" then
        table.insert(items, tostring(k) .. " = {...}")
      else
        table.insert(items, tostring(k) .. " = " .. tostring(v))
      end
    end
    return "{" .. table.concat(items, ", ") .. "}"
  end,
  api = {
    nvim_create_buf = function() return 1 end,
    nvim_buf_set_name = function() end,
    nvim_buf_set_option = function() end,
    nvim_set_current_buf = function() end,
    nvim_get_current_win = function() return 1 end,
    nvim_win_set_option = function() end,
    nvim_buf_is_valid = function() return true end,
    nvim_win_is_valid = function() return true end,
    nvim_buf_set_lines = function() end,
    nvim_win_get_cursor = function() return {1, 0} end,
  },
  fn = {
    bufnr = function() return -1 end,
  },
  cmd = function() end,
  keymap = {
    set = function() end,
  },
  notify = function() end,
  log = {
    levels = {
      INFO = 1,
      WARN = 2,
      ERROR = 3,
    }
  }
}

local models = require('samplanner.domain.models')

-- Helper function to check if a Job should be filtered
-- Replicated from tree.lua for testing
local function should_filter_job(node, task, filters)
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
  if is_completed and not filters.show_completed_jobs then
    return true  -- Hide completed jobs
  end
  if not is_completed and not filters.show_incomplete_jobs then
    return true  -- Hide incomplete jobs
  end

  return false
end

describe("Tree Filtering", function()
  describe("should_filter_job", function()
    it("should not filter non-Job nodes", function()
      local area_node = models.StructureNode.new("1", "Area", {})
      local component_node = models.StructureNode.new("1.1", "Component", {})
      local filters = { show_completed_jobs = false, show_incomplete_jobs = true }

      assert.is_false(should_filter_job(area_node, nil, filters))
      assert.is_false(should_filter_job(component_node, nil, filters))
    end)

    it("should hide completed jobs when show_completed_jobs is false", function()
      local job_node = models.StructureNode.new("1.1.1", "Job", {})
      local job_details = models.JobDetails.new({ completed = true })
      local task = models.Task.new("1.1.1", "Completed Job", job_details, nil, {}, "")
      local filters = { show_completed_jobs = false, show_incomplete_jobs = true }

      assert.is_true(should_filter_job(job_node, task, filters))
    end)

    it("should show completed jobs when show_completed_jobs is true", function()
      local job_node = models.StructureNode.new("1.1.1", "Job", {})
      local job_details = models.JobDetails.new({ completed = true })
      local task = models.Task.new("1.1.1", "Completed Job", job_details, nil, {}, "")
      local filters = { show_completed_jobs = true, show_incomplete_jobs = true }

      assert.is_false(should_filter_job(job_node, task, filters))
    end)

    it("should hide incomplete jobs when show_incomplete_jobs is false", function()
      local job_node = models.StructureNode.new("1.1.1", "Job", {})
      local job_details = models.JobDetails.new({ completed = false })
      local task = models.Task.new("1.1.1", "Incomplete Job", job_details, nil, {}, "")
      local filters = { show_completed_jobs = true, show_incomplete_jobs = false }

      assert.is_true(should_filter_job(job_node, task, filters))
    end)

    it("should show incomplete jobs when show_incomplete_jobs is true", function()
      local job_node = models.StructureNode.new("1.1.1", "Job", {})
      local job_details = models.JobDetails.new({ completed = false })
      local task = models.Task.new("1.1.1", "Incomplete Job", job_details, nil, {}, "")
      local filters = { show_completed_jobs = false, show_incomplete_jobs = true }

      assert.is_false(should_filter_job(job_node, task, filters))
    end)

    it("should use default filters (hide completed, show incomplete)", function()
      local job_node = models.StructureNode.new("1.1.1", "Job", {})
      local completed_job_details = models.JobDetails.new({ completed = true })
      local incomplete_job_details = models.JobDetails.new({ completed = false })
      local completed_task = models.Task.new("1.1.1", "Completed", completed_job_details, nil, {}, "")
      local incomplete_task = models.Task.new("1.1.2", "Incomplete", incomplete_job_details, nil, {}, "")

      -- Default filters: show_completed_jobs = false, show_incomplete_jobs = true
      local filters = { show_completed_jobs = false, show_incomplete_jobs = true }

      assert.is_true(should_filter_job(job_node, completed_task, filters))
      assert.is_false(should_filter_job(job_node, incomplete_task, filters))
    end)

    it("should handle job without task", function()
      local job_node = models.StructureNode.new("1.1.1", "Job", {})
      local filters = { show_completed_jobs = false, show_incomplete_jobs = true }

      -- Job without task should be treated as incomplete
      assert.is_false(should_filter_job(job_node, nil, filters))
    end)

    it("should handle job without details", function()
      local job_node = models.StructureNode.new("1.1.1", "Job", {})
      local task = models.Task.new("1.1.1", "Job", "", nil, {}, "")
      local filters = { show_completed_jobs = false, show_incomplete_jobs = true }

      -- Job without details should be treated as incomplete
      assert.is_false(should_filter_job(job_node, task, filters))
    end)

    it("should handle both filters off (hide all jobs)", function()
      local job_node = models.StructureNode.new("1.1.1", "Job", {})
      local completed_job_details = models.JobDetails.new({ completed = true })
      local incomplete_job_details = models.JobDetails.new({ completed = false })
      local completed_task = models.Task.new("1.1.1", "Completed", completed_job_details, nil, {}, "")
      local incomplete_task = models.Task.new("1.1.2", "Incomplete", incomplete_job_details, nil, {}, "")
      local filters = { show_completed_jobs = false, show_incomplete_jobs = false }

      assert.is_true(should_filter_job(job_node, completed_task, filters))
      assert.is_true(should_filter_job(job_node, incomplete_task, filters))
    end)

    it("should handle both filters on (show all jobs)", function()
      local job_node = models.StructureNode.new("1.1.1", "Job", {})
      local completed_job_details = models.JobDetails.new({ completed = true })
      local incomplete_job_details = models.JobDetails.new({ completed = false })
      local completed_task = models.Task.new("1.1.1", "Completed", completed_job_details, nil, {}, "")
      local incomplete_task = models.Task.new("1.1.2", "Incomplete", incomplete_job_details, nil, {}, "")
      local filters = { show_completed_jobs = true, show_incomplete_jobs = true }

      assert.is_false(should_filter_job(job_node, completed_task, filters))
      assert.is_false(should_filter_job(job_node, incomplete_task, filters))
    end)
  end)
end)
