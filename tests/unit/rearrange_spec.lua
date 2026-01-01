-- Unit tests for tree rearrangement operations
-- Run with: luajit tests/unit/rearrange_spec.lua

-- Add the lua directory to the package path
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua;./tests/helpers/?.lua"

-- Load mini test framework
require('mini_test')

-- Use dkjson for proper JSON handling
package.path = package.path .. ";./tests/deps/dkjson/?.lua"
local dkjson = require('dkjson')

-- Mock vim global for testing outside Neovim
_G.vim = {
  fn = {
    mkdir = function(path, flags)
      os.execute("mkdir -p " .. path)
    end,
    json_encode = function(data)
      return dkjson.encode(data, {indent = true})
    end,
    json_decode = function(str)
      return dkjson.decode(str)
    end,
    isdirectory = function(path)
      local ok, err, code = os.rename(path, path)
      if not ok and code == 13 then
        return 1
      end
      return ok and 1 or 0
    end,
    glob = function(pattern, nosuf, list)
      local cmd = "ls " .. pattern .. " 2>/dev/null"
      local handle = io.popen(cmd)
      if not handle then return {} end
      local result = handle:read("*a")
      handle:close()

      local files = {}
      for file in result:gmatch("[^\r\n]+") do
        table.insert(files, file)
      end
      return files
    end,
    fnamemodify = function(path, mods)
      if mods == ":t:r" then
        local filename = path:match("([^/]+)$")
        return filename:match("(.+)%..+$") or filename
      end
      return path
    end
  },
  tbl_contains = function(tbl, val)
    for _, v in ipairs(tbl) do
      if v == val then
        return true
      end
    end
    return false
  end,
  tbl_deep_extend = function(behavior, ...)
    local result = {}
    for _, tbl in ipairs({...}) do
      for k, v in pairs(tbl) do
        result[k] = v
      end
    end
    return result
  end
}

-- Mock samplanner module with test directory
local test_dir = "./tests/tmp/rearrange"
package.loaded['samplanner'] = {
  config = {
    filepath = test_dir
  }
}

local operations = require('samplanner.domain.operations')

describe("Swap Siblings Operation", function()
  local project

  before_each(function()
    os.execute("rm -rf " .. test_dir)
    os.execute("mkdir -p " .. test_dir)
    project, _ = operations.create_project("proj-1", "SwapTest")

    -- Create a tree structure for testing:
    -- 1 Area1
    -- 2 Area2
    -- 3 Area3
    operations.add_node(project, nil, "Area", "Area1")
    operations.add_node(project, nil, "Area", "Area2")
    operations.add_node(project, nil, "Area", "Area3")
  end)

  after_each(function()
    os.execute("rm -rf " .. test_dir)
  end)

  it("should swap node down with next sibling", function()
    local success, err = operations.swap_siblings(project, "1", "down")

    assert.is_true(success)
    assert.is_nil(err)

    -- Area1 should now be at position 2
    assert.is_not_nil(project.structure["2"])
    assert.are.equal("Area1", project.task_list["2"].name)

    -- Area2 should now be at position 1
    assert.is_not_nil(project.structure["1"])
    assert.are.equal("Area2", project.task_list["1"].name)

    -- Area3 should still be at position 3
    assert.is_not_nil(project.structure["3"])
    assert.are.equal("Area3", project.task_list["3"].name)
  end)

  it("should swap node up with previous sibling", function()
    local success, err = operations.swap_siblings(project, "2", "up")

    assert.is_true(success)
    assert.is_nil(err)

    -- Area2 should now be at position 1
    assert.is_not_nil(project.structure["1"])
    assert.are.equal("Area2", project.task_list["1"].name)

    -- Area1 should now be at position 2
    assert.is_not_nil(project.structure["2"])
    assert.are.equal("Area1", project.task_list["2"].name)
  end)

  it("should not move up when already at top", function()
    local success, err = operations.swap_siblings(project, "1", "up")

    assert.is_false(success)
    assert.is_not_nil(err)
    assert.is_true(string.find(err, "already at the top") ~= nil)
  end)

  it("should not move down when already at bottom", function()
    local success, err = operations.swap_siblings(project, "3", "down")

    assert.is_false(success)
    assert.is_not_nil(err)
    assert.is_true(string.find(err, "already at the bottom") ~= nil)
  end)

  it("should return error for invalid direction", function()
    local success, err = operations.swap_siblings(project, "1", "invalid")

    assert.is_false(success)
    assert.is_not_nil(err)
    assert.is_true(string.find(err, "Invalid direction") ~= nil)
  end)

  it("should swap nested nodes and update all descendant IDs", function()
    -- Add children to Area1
    operations.add_node(project, "1", "Component", "Comp1")
    operations.add_node(project, "1.1", "Job", "Job1")

    -- Swap Area1 down
    local success, err = operations.swap_siblings(project, "1", "down")

    assert.is_true(success)
    assert.is_nil(err)

    -- Area1 is now at position 2 with its children
    assert.is_not_nil(project.structure["2"])
    assert.is_not_nil(project.structure["2"].subtasks["2.1"])
    assert.is_not_nil(project.structure["2"].subtasks["2.1"].subtasks["2.1.1"])

    -- Verify task IDs were updated
    assert.is_not_nil(project.task_list["2.1"])
    assert.are.equal("Comp1", project.task_list["2.1"].name)
    assert.is_not_nil(project.task_list["2.1.1"])
    assert.are.equal("Job1", project.task_list["2.1.1"].name)
  end)

  it("should work with multiple levels of siblings", function()
    -- Add siblings under Area1
    operations.add_node(project, "1", "Component", "Comp1")
    operations.add_node(project, "1", "Component", "Comp2")
    operations.add_node(project, "1", "Component", "Comp3")

    -- Swap Comp2 down
    local success, err = operations.swap_siblings(project, "1.2", "down")

    assert.is_true(success)
    assert.is_nil(err)

    -- Comp2 should now be at 1.3
    assert.is_not_nil(project.structure["1"].subtasks["1.3"])
    assert.are.equal("Comp2", project.task_list["1.3"].name)

    -- Comp3 should now be at 1.2
    assert.is_not_nil(project.structure["1"].subtasks["1.2"])
    assert.are.equal("Comp3", project.task_list["1.2"].name)
  end)
end)

describe("Indent Node Operation", function()
  local project

  before_each(function()
    os.execute("rm -rf " .. test_dir)
    os.execute("mkdir -p " .. test_dir)
    project, _ = operations.create_project("proj-1", "IndentTest")

    -- Create a tree structure:
    -- 1 Area1
    -- 2 Area2
    -- 3 Area3
    operations.add_node(project, nil, "Area", "Area1")
    operations.add_node(project, nil, "Area", "Area2")
    operations.add_node(project, nil, "Area", "Area3")
  end)

  after_each(function()
    os.execute("rm -rf " .. test_dir)
  end)

  it("should indent node under previous sibling", function()
    local success, err = operations.indent_node(project, "2")

    assert.is_true(success)
    assert.is_nil(err)

    -- Area2 should now be under Area1
    assert.is_not_nil(project.structure["1"].subtasks["1.1"])
    assert.are.equal("Area2", project.task_list["1.1"].name)

    -- Area3 should be renumbered to 2 (moved up after Area2 was indented)
    assert.is_not_nil(project.structure["2"])
    assert.are.equal("Area3", project.task_list["2"].name)
  end)

  it("should not indent first sibling", function()
    local success, err = operations.indent_node(project, "1")

    assert.is_false(success)
    assert.is_not_nil(err)
    assert.is_true(string.find(err, "no previous sibling") ~= nil)
  end)

  it("should indent node with children", function()
    -- Add children to Area2
    operations.add_node(project, "2", "Component", "Comp1")
    operations.add_node(project, "2.1", "Job", "Job1")

    local success, err = operations.indent_node(project, "2")

    assert.is_true(success)
    assert.is_nil(err)

    -- Area2 and its children should be under Area1
    assert.is_not_nil(project.structure["1"].subtasks["1.1"])
    assert.is_not_nil(project.structure["1"].subtasks["1.1"].subtasks["1.1.1"])
    assert.is_not_nil(project.structure["1"].subtasks["1.1"].subtasks["1.1.1"].subtasks["1.1.1.1"])

    -- Verify tasks
    assert.are.equal("Area2", project.task_list["1.1"].name)
    assert.are.equal("Comp1", project.task_list["1.1.1"].name)
    assert.are.equal("Job1", project.task_list["1.1.1.1"].name)
  end)

  it("should work at nested levels", function()
    -- Create nested structure:
    -- 1 Area1
    --   1.1 Comp1
    --   1.2 Comp2
    operations.add_node(project, "1", "Component", "Comp1")
    operations.add_node(project, "1", "Component", "Comp2")

    -- Indent Comp2 under Comp1
    local success, err = operations.indent_node(project, "1.2")

    assert.is_true(success)
    assert.is_nil(err)

    -- Comp2 should be under Comp1
    assert.is_not_nil(project.structure["1"].subtasks["1.1"].subtasks["1.1.1"])
    assert.are.equal("Comp2", project.task_list["1.1.1"].name)
  end)
end)

describe("Outdent Node Operation", function()
  local project

  before_each(function()
    os.execute("rm -rf " .. test_dir)
    os.execute("mkdir -p " .. test_dir)
    project, _ = operations.create_project("proj-1", "OutdentTest")

    -- Create a tree structure:
    -- 1 Area1
    --   1.1 Comp1
    --   1.2 Comp2
    -- 2 Area2
    operations.add_node(project, nil, "Area", "Area1")
    operations.add_node(project, "1", "Component", "Comp1")
    operations.add_node(project, "1", "Component", "Comp2")
    operations.add_node(project, nil, "Area", "Area2")
  end)

  after_each(function()
    os.execute("rm -rf " .. test_dir)
  end)

  it("should outdent node to parent's level", function()
    local success, err = operations.outdent_node(project, "1.1")

    assert.is_true(success)
    assert.is_nil(err)

    -- Comp1 should now be at root level at position 3 (after Area2)
    assert.is_not_nil(project.structure["3"])
    assert.are.equal("Comp1", project.task_list["3"].name)

    -- Area2 should still be at position 2
    assert.is_not_nil(project.structure["2"])
    assert.are.equal("Area2", project.task_list["2"].name)

    -- Comp2 should be renumbered to 1.1
    assert.is_not_nil(project.structure["1"].subtasks["1.1"])
    assert.are.equal("Comp2", project.task_list["1.1"].name)
  end)

  it("should not outdent root-level node", function()
    local success, err = operations.outdent_node(project, "1")

    assert.is_false(success)
    assert.is_not_nil(err)
    assert.is_true(string.find(err, "already at root level") ~= nil)
  end)

  it("should outdent node with children", function()
    -- Add child to Comp1
    operations.add_node(project, "1.1", "Job", "Job1")

    local success, err = operations.outdent_node(project, "1.1")

    assert.is_true(success)
    assert.is_nil(err)

    -- Comp1 and Job1 should be at root level at position 3
    assert.is_not_nil(project.structure["3"])
    assert.are.equal("Comp1", project.task_list["3"].name)
    assert.is_not_nil(project.structure["3"].subtasks["3.1"])
    assert.are.equal("Job1", project.task_list["3.1"].name)
  end)

  it("should work with deeply nested nodes", function()
    -- Create deeper structure:
    -- 1 Area1
    --   1.1 Comp1
    --     1.1.1 Job1
    operations.add_node(project, "1.1", "Job", "Job1")

    -- Outdent Job1 to Comp level
    local success, err = operations.outdent_node(project, "1.1.1")

    assert.is_true(success)
    assert.is_nil(err)

    -- Job1 should be at same level as Comp1/Comp2 (renumbered to 1.3, after 1.1 and 1.2)
    assert.is_not_nil(project.structure["1"].subtasks["1.3"])
    assert.are.equal("Job1", project.task_list["1.3"].name)
  end)

  it("should outdent multiple times to reach root", function()
    -- Start with 1.1.1 (deeply nested)
    operations.add_node(project, "1.1", "Job", "Job1")

    -- First outdent: 1.1.1 -> 1.3 (after Comp1 and Comp2)
    local success1, _ = operations.outdent_node(project, "1.1.1")
    assert.is_true(success1)

    -- After renumber, Job1 should be 1.3
    assert.is_not_nil(project.structure["1"].subtasks["1.3"])
    assert.are.equal("Job1", project.task_list["1.3"].name)

    -- Second outdent: 1.3 -> root level (position 3, after Area2)
    local success2, _ = operations.outdent_node(project, "1.3")
    assert.is_true(success2)

    -- Job1 should now be at root (renumbered to 3)
    assert.is_not_nil(project.structure["3"])
    assert.are.equal("Job1", project.task_list["3"].name)
  end)
end)

describe("Rearrangement with Tasks", function()
  local project

  before_each(function()
    os.execute("rm -rf " .. test_dir)
    os.execute("mkdir -p " .. test_dir)
    project, _ = operations.create_project("proj-1", "TaskTest")

    -- Create structure with detailed tasks
    operations.add_node(project, nil, "Area", "Area1")
    operations.add_node(project, nil, "Area", "Area2")
    operations.update_task(project, "1", { details = "Details for Area1" })
    operations.update_task(project, "2", { details = "Details for Area2" })
  end)

  after_each(function()
    os.execute("rm -rf " .. test_dir)
  end)

  it("should preserve task details when swapping", function()
    operations.swap_siblings(project, "1", "down")

    -- Task details should be preserved
    assert.are.equal("Details for Area1", project.task_list["2"].details)
    assert.are.equal("Details for Area2", project.task_list["1"].details)
  end)

  it("should preserve task details when indenting", function()
    operations.add_node(project, nil, "Area", "Area3")
    operations.update_task(project, "2", { details = "Details for Area2" })

    operations.indent_node(project, "2")

    -- After renumbering, Area2 should be 1.1
    assert.is_not_nil(project.task_list["1.1"])
    assert.are.equal("Details for Area2", project.task_list["1.1"].details)
  end)

  it("should preserve task details when outdenting", function()
    operations.add_node(project, "1", "Component", "Comp1")
    operations.update_task(project, "1.1", { details = "Details for Comp1" })

    operations.outdent_node(project, "1.1")

    -- After renumbering, Comp1 should be at root level (position 3, after Area2)
    assert.is_not_nil(project.task_list["3"])
    assert.are.equal("Details for Comp1", project.task_list["3"].details)
  end)
end)

-- Run summary at end
require('mini_test').run_summary()
