-- Unit tests for domain operations
-- Run with: luajit tests/unit/operations_spec.lua

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
local test_dir = "./tests/tmp/operations"
package.loaded['samplanner'] = {
  config = {
    filepath = test_dir
  }
}

local models = require('samplanner.domain.models')
local operations = require('samplanner.domain.operations')

describe("Project Management", function()
  before_each(function()
    os.execute("rm -rf " .. test_dir)
    os.execute("mkdir -p " .. test_dir)
  end)

  after_each(function()
    os.execute("rm -rf " .. test_dir)
  end)

  it("should create a new project", function()
    local project, err = operations.create_project("proj-1", "TestProject")

    assert.is_nil(err)
    assert.is_not_nil(project)
    assert.are.equal("proj-1", project.project_info.id)
    assert.are.equal("TestProject", project.project_info.name)

    -- Verify file was created
    local file = io.open(test_dir .. "/TestProject.json", "r")
    assert.is_not_nil(file)
    if file then file:close() end
  end)

  it("should load an existing project", function()
    -- Create a project first
    operations.create_project("proj-1", "LoadTest")

    -- Load it
    local loaded, err = operations.load_project("LoadTest")

    assert.is_nil(err)
    assert.is_not_nil(loaded)
    assert.are.equal("proj-1", loaded.project_info.id)
  end)

  it("should delete a project", function()
    operations.create_project("proj-1", "DeleteTest")

    local success, err = operations.delete_project("DeleteTest")

    assert.is_true(success)
    assert.is_nil(err)

    -- Verify file was deleted
    local file = io.open(test_dir .. "/DeleteTest.json", "r")
    assert.is_nil(file)
  end)
end)

describe("Tree Structure Operations", function()
  local project

  before_each(function()
    os.execute("rm -rf " .. test_dir)
    os.execute("mkdir -p " .. test_dir)
    project, _ = operations.create_project("proj-1", "TreeTest")
  end)

  after_each(function()
    os.execute("rm -rf " .. test_dir)
  end)

  it("should add a root-level node", function()
    local node_id, err = operations.add_node(project, nil, "Area", "Authentication")

    assert.is_nil(err)
    assert.are.equal("1", node_id)
    assert.is_not_nil(project.structure["1"])
    assert.are.equal("Area", project.structure["1"].type)
  end)

  it("should add a child node", function()
    operations.add_node(project, nil, "Area", "Authentication")
    local child_id, err = operations.add_node(project, "1", "Component", "Login")

    assert.is_nil(err)
    assert.are.equal("1.1", child_id)
    assert.is_not_nil(project.structure["1"].subtasks["1.1"])
    assert.are.equal("Component", project.structure["1"].subtasks["1.1"].type)
  end)

  it("should create associated task when adding node with name", function()
    operations.add_node(project, nil, "Area", "Authentication")

    assert.is_not_nil(project.task_list["1"])
    assert.are.equal("Authentication", project.task_list["1"].name)
  end)

  it("should remove a node and its children", function()
    operations.add_node(project, nil, "Area", "Auth")
    operations.add_node(project, "1", "Component", "Login")
    operations.add_node(project, "1.1", "Job", "Form")

    local success, err = operations.remove_node(project, "1")

    assert.is_true(success)
    assert.is_nil(err)
    assert.is_nil(project.structure["1"])
    -- Tasks should also be removed
    assert.is_nil(project.task_list["1"])
    assert.is_nil(project.task_list["1.1"])
    assert.is_nil(project.task_list["1.1.1"])
  end)

  it("should move a node to a new parent", function()
    operations.add_node(project, nil, "Area", "Area1")
    operations.add_node(project, nil, "Area", "Area2")
    operations.add_node(project, "1", "Component", "ToMove")

    local new_id, err = operations.move_node(project, "1.1", "2")

    assert.is_nil(err)
    assert.are.equal("2.1", new_id)
    -- Old location should be empty
    assert.is_nil(project.structure["1"].subtasks["1.1"])
    -- New location should have the node
    assert.is_not_nil(project.structure["2"].subtasks["2.1"])
  end)

  it("should renumber structure for consistent ordering", function()
    operations.add_node(project, nil, "Area", "First")
    operations.add_node(project, nil, "Area", "Second")
    operations.add_node(project, nil, "Area", "Third")
    -- Remove the middle one
    operations.remove_node(project, "2")

    -- Now we have nodes 1 and 3, renumber should make them 1 and 2
    local success, err = operations.renumber_structure(project)

    assert.is_true(success)
    assert.is_nil(err)
    assert.is_not_nil(project.structure["1"])
    assert.is_not_nil(project.structure["2"])
    assert.is_nil(project.structure["3"])
  end)

  it("should display tree structure", function()
    operations.add_node(project, nil, "Area", "Authentication")
    operations.add_node(project, "1", "Component", "Login")
    operations.add_node(project, "1.1", "Job", "Create Form")

    local display = operations.get_tree_display(project)

    assert.is_not_nil(display)
    -- Check that the display contains expected elements
    assert.is_true(string.find(display, "1 Area: Authentication") ~= nil)
    assert.is_true(string.find(display, "1.1 Component: Login") ~= nil)
    assert.is_true(string.find(display, "1.1.1 Job: Create Form") ~= nil)
  end)
end)

describe("Task Management", function()
  local project

  before_each(function()
    os.execute("rm -rf " .. test_dir)
    os.execute("mkdir -p " .. test_dir)
    project, _ = operations.create_project("proj-1", "TaskTest")
  end)

  after_each(function()
    os.execute("rm -rf " .. test_dir)
  end)

  it("should create a task", function()
    local models = require('samplanner.domain.models')
    local estimation = models.Estimation.new({ work_type = "bugfix", confidence = "high" })
    local task, err = operations.create_task(project, "task-1", "Test Task", "Details here", estimation, {"bug", "urgent"}, "some notes")

    assert.is_nil(err)
    assert.is_not_nil(task)
    assert.are.equal("task-1", task.id)
    assert.are.equal("Test Task", task.name)
    assert.are.equal("Details here", task.details)
    assert.are.equal("bugfix", task.estimation.work_type)
    assert.are.equal("high", task.estimation.confidence)
    assert.are.same({"bug", "urgent"}, task.tags)
    assert.are.equal("some notes", task.notes)
  end)

  it("should create a task without estimation", function()
    local task, err = operations.create_task(project, "task-2", "Test Task", "Details", nil, {"tag"}, "notes")

    assert.is_nil(err)
    assert.is_not_nil(task)
    assert.is_nil(task.estimation)
    assert.are.equal("notes", task.notes)
  end)

  it("should add task tags to project tags", function()
    operations.create_task(project, "task-1", "Test", "", nil, {"new-tag"}, "")

    assert.is_true(vim.tbl_contains(project.tags, "new-tag"))
  end)

  it("should not allow duplicate task IDs", function()
    operations.create_task(project, "task-1", "First", "", nil, {}, "")
    local task, err = operations.create_task(project, "task-1", "Second", "", nil, {}, "")

    assert.is_nil(task)
    assert.is_not_nil(err)
  end)

  it("should update a task", function()
    operations.create_task(project, "task-1", "Original", "", nil, {}, "")

    local task, err = operations.update_task(project, "task-1", {
      name = "Updated",
      details = "New details"
    })

    assert.is_nil(err)
    assert.are.equal("Updated", task.name)
    assert.are.equal("New details", task.details)
  end)

  it("should delete a task", function()
    operations.create_task(project, "task-1", "ToDelete", "", nil, {}, "")

    local success, err = operations.delete_task(project, "task-1")

    assert.is_true(success)
    assert.is_nil(err)
    assert.is_nil(project.task_list["task-1"])
  end)

  it("should link task to node", function()
    operations.add_node(project, nil, "Area", "")
    operations.create_task(project, "task-1", "Test Task", "", nil, {}, "")

    local success, err = operations.link_task_to_node(project, "task-1", "1")

    assert.is_true(success)
    assert.is_nil(err)
    -- Task should now be at node ID
    assert.is_not_nil(project.task_list["1"])
    assert.are.equal("Test Task", project.task_list["1"].name)
    -- Old ID should be gone
    assert.is_nil(project.task_list["task-1"])
  end)
end)

describe("Time Log Operations", function()
  local project

  before_each(function()
    os.execute("rm -rf " .. test_dir)
    os.execute("mkdir -p " .. test_dir)
    project, _ = operations.create_project("proj-1", "TimeTest")
  end)

  after_each(function()
    os.execute("rm -rf " .. test_dir)
  end)

  it("should start a session", function()
    local index, err = operations.start_session(project)

    assert.is_nil(err)
    assert.are.equal(1, index)
    assert.is_not_nil(project.time_log[1])
    assert.is_not_nil(project.time_log[1].start_timestamp)
    assert.are.equal("", project.time_log[1].end_timestamp)
  end)

  it("should stop a session", function()
    operations.start_session(project)

    local success, err = operations.stop_session(project, 1)

    assert.is_true(success)
    assert.is_nil(err)
    assert.is_true(project.time_log[1].end_timestamp ~= "")
  end)

  it("should not stop an already stopped session", function()
    operations.start_session(project)
    operations.stop_session(project, 1)

    local success, err = operations.stop_session(project, 1)

    assert.is_false(success)
    assert.is_not_nil(err)
  end)

  it("should update session notes", function()
    operations.start_session(project)

    local session, err = operations.update_session(project, 1, {
      notes = "Worked on feature X",
      interruptions = "Phone call",
      interruption_minutes = 15
    })

    assert.is_nil(err)
    assert.are.equal("Worked on feature X", session.notes)
    assert.are.equal("Phone call", session.interruptions)
    assert.are.equal(15, session.interruption_minutes)
  end)

  it("should update session with new PSP and productivity fields", function()
    operations.start_session(project)

    local session, err = operations.update_session(project, 1, {
      session_type = "testing",
      planned_duration_minutes = 120,
      focus_rating = 5,
      energy_level = { start = 4, ["end"] = 3 },
      context_switches = 3,
      defects = { found = {"Bug 1", "Bug 2"}, fixed = {"Bug 3"} },
      deliverables = {"Feature A", "Feature B"},
      blockers = {"Waiting on API"},
      retrospective = {
        what_went_well = {"Good tests"},
        what_needs_improvement = {"Documentation"},
        lessons_learned = {"Test first"}
      }
    })

    assert.is_nil(err)
    assert.are.equal("testing", session.session_type)
    assert.are.equal(120, session.planned_duration_minutes)
    assert.are.equal(5, session.focus_rating)
    assert.are.equal(4, session.energy_level.start)
    assert.are.equal(3, session.energy_level["end"])
    assert.are.equal(3, session.context_switches)
    assert.are.same({"Bug 1", "Bug 2"}, session.defects.found)
    assert.are.same({"Bug 3"}, session.defects.fixed)
    assert.are.same({"Feature A", "Feature B"}, session.deliverables)
    assert.are.same({"Waiting on API"}, session.blockers)
    assert.are.same({"Good tests"}, session.retrospective.what_went_well)
    assert.are.same({"Documentation"}, session.retrospective.what_needs_improvement)
    assert.are.same({"Test first"}, session.retrospective.lessons_learned)
  end)

  it("should add task to session", function()
    operations.start_session(project)
    operations.create_task(project, "task-1", "Test", "", nil, {}, "")

    local success, err = operations.add_task_to_session(project, 1, "task-1")

    assert.is_true(success)
    assert.is_nil(err)
    assert.is_true(vim.tbl_contains(project.time_log[1].tasks, "task-1"))
  end)

  it("should find active session", function()
    operations.start_session(project)
    operations.start_session(project)
    operations.stop_session(project, 1)

    local index, session = operations.get_active_session(project)

    assert.are.equal(2, index)
    assert.is_not_nil(session)
    assert.are.equal("", session.end_timestamp)
  end)

  it("should return nil when no active session", function()
    operations.start_session(project)
    operations.stop_session(project, 1)

    local index, session = operations.get_active_session(project)

    assert.is_nil(index)
    assert.is_nil(session)
  end)
end)

describe("Tag Operations", function()
  local project

  before_each(function()
    os.execute("rm -rf " .. test_dir)
    os.execute("mkdir -p " .. test_dir)
    project, _ = operations.create_project("proj-1", "TagTest")
  end)

  after_each(function()
    os.execute("rm -rf " .. test_dir)
  end)

  it("should add a tag to project", function()
    local success, err = operations.add_tag(project, "new-tag")

    assert.is_true(success)
    assert.is_nil(err)
    assert.is_true(vim.tbl_contains(project.tags, "new-tag"))
  end)

  it("should not duplicate tags", function()
    operations.add_tag(project, "tag1")
    operations.add_tag(project, "tag1")

    local count = 0
    for _, t in ipairs(project.tags) do
      if t == "tag1" then count = count + 1 end
    end
    assert.are.equal(1, count)
  end)

  it("should remove a tag from project and all tasks", function()
    operations.add_tag(project, "remove-me")
    operations.create_task(project, "task-1", "Test", "", "", {"remove-me", "keep"})

    local success, err = operations.remove_tag(project, "remove-me")

    assert.is_true(success)
    assert.is_nil(err)
    assert.is_false(vim.tbl_contains(project.tags, "remove-me"))
    assert.is_false(vim.tbl_contains(project.task_list["task-1"].tags, "remove-me"))
    assert.is_true(vim.tbl_contains(project.task_list["task-1"].tags, "keep"))
  end)

  it("should tag a task", function()
    operations.create_task(project, "task-1", "Test", "", nil, {}, "")

    local success, err = operations.tag_task(project, "task-1", "new-tag")

    assert.is_true(success)
    assert.is_nil(err)
    assert.is_true(vim.tbl_contains(project.task_list["task-1"].tags, "new-tag"))
    -- Tag should also be added to project
    assert.is_true(vim.tbl_contains(project.tags, "new-tag"))
  end)

  it("should untag a task", function()
    operations.create_task(project, "task-1", "Test", "", "", {"remove-me"})

    local success, err = operations.untag_task(project, "task-1", "remove-me")

    assert.is_true(success)
    assert.is_nil(err)
    assert.is_false(vim.tbl_contains(project.task_list["task-1"].tags, "remove-me"))
  end)

  it("should search tasks by single tag", function()
    operations.create_task(project, "task-1", "Match", "", "", {"target"})
    operations.create_task(project, "task-2", "No Match", "", "", {"other"})
    operations.create_task(project, "task-3", "Also Match", "", "", {"target", "other"})

    local results = operations.search_by_tag(project, "target")

    assert.are.equal(2, #results)
  end)

  it("should search tasks by multiple tags (match all)", function()
    operations.create_task(project, "task-1", "Both", "", "", {"tag1", "tag2"})
    operations.create_task(project, "task-2", "One", "", "", {"tag1"})
    operations.create_task(project, "task-3", "None", "", "", {"tag3"})

    local results = operations.search_by_tags(project, {"tag1", "tag2"}, true)

    assert.are.equal(1, #results)
    assert.are.equal("Both", results[1].name)
  end)

  it("should search tasks by multiple tags (match any)", function()
    operations.create_task(project, "task-1", "Both", "", "", {"tag1", "tag2"})
    operations.create_task(project, "task-2", "One", "", "", {"tag1"})
    operations.create_task(project, "task-3", "None", "", "", {"tag3"})

    local results = operations.search_by_tags(project, {"tag1", "tag2"}, false)

    assert.are.equal(2, #results)
  end)
end)

-- Run summary at end
require('mini_test').run_summary()
