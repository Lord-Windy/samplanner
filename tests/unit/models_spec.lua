-- Unit tests for domain models
-- Run with: luajit tests/unit/models_spec.lua

-- Add the lua directory to the package path
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua;./tests/helpers/?.lua"

-- Load mini test framework
require('mini_test')

local models = require('samplanner.domain.models')

describe("ProjectInfo", function()
  it("should create a new ProjectInfo instance", function()
    local info = models.ProjectInfo.new("proj-1", "Test Project")
    assert.are.equal("proj-1", info.id)
    assert.are.equal("Test Project", info.name)
  end)

  it("should use empty strings as defaults", function()
    local info = models.ProjectInfo.new()
    assert.are.equal("", info.id)
    assert.are.equal("", info.name)
  end)
end)

describe("Estimation", function()
  it("should create a new Estimation instance", function()
    local est = models.Estimation.new({
      work_type = "new_work",
      assumptions = {"assumption 1"},
      effort = { method = "gut_feel", base_hours = 4, buffer_percent = 20, buffer_reason = "unknowns", total_hours = 5 },
      confidence = "med",
      schedule = { start_date = "2025-01-01", target_finish = "2025-01-05", milestones = {} },
      post_estimate_notes = { could_be_smaller = {}, could_be_bigger = {}, ignored_last_time = {} }
    })
    assert.are.equal("new_work", est.work_type)
    assert.are.same({"assumption 1"}, est.assumptions)
    assert.are.equal("gut_feel", est.effort.method)
    assert.are.equal(4, est.effort.base_hours)
    assert.are.equal("med", est.confidence)
    assert.are.equal("2025-01-01", est.schedule.start_date)
  end)

  it("should use defaults for missing parameters", function()
    local est = models.Estimation.new()
    assert.are.equal("", est.work_type)
    assert.are.same({}, est.assumptions)
    assert.are.equal("", est.effort.method)
    assert.are.equal(0, est.effort.base_hours)
    assert.are.equal("", est.confidence)
  end)

  it("should detect empty estimation", function()
    local est = models.Estimation.new()
    assert.is_true(est:is_empty())

    local est2 = models.Estimation.new({ work_type = "bugfix" })
    assert.is_false(est2:is_empty())
  end)
end)

describe("Task", function()
  it("should create a new Task instance with structured estimation", function()
    local est = models.Estimation.new({ work_type = "new_work", confidence = "high" })
    local task = models.Task.new("1.1", "Task Name", "Details", est, {"tag1", "tag2"}, "some notes")
    assert.are.equal("1.1", task.id)
    assert.are.equal("Task Name", task.name)
    assert.are.equal("Details", task.details)
    assert.are.equal("new_work", task.estimation.work_type)
    assert.are.equal("high", task.estimation.confidence)
    assert.are.same({"tag1", "tag2"}, task.tags)
    assert.are.equal("some notes", task.notes)
  end)

  it("should use defaults for missing parameters", function()
    local task = models.Task.new()
    assert.are.equal("", task.id)
    assert.are.equal("", task.name)
    assert.are.equal("", task.details)
    assert.is_nil(task.estimation)
    assert.are.same({}, task.tags)
    assert.are.equal("", task.notes)
  end)

  it("should accept estimation as table data", function()
    local task = models.Task.new("1.1", "Task", "", { work_type = "bugfix" }, {}, "")
    assert.are.equal("bugfix", task.estimation.work_type)
  end)
end)

describe("StructureNode", function()
  it("should create a new StructureNode instance", function()
    local node = models.StructureNode.new("1", "Area", {})
    assert.are.equal("1", node.id)
    assert.are.equal("Area", node.type)
    assert.are.same({}, node.subtasks)
  end)

  it("should default to Job type", function()
    local node = models.StructureNode.new()
    assert.are.equal("Job", node.type)
  end)

  it("should handle nested subtasks", function()
    local subtask = models.StructureNode.new("1.1", "Component", {})
    local node = models.StructureNode.new("1", "Area", {["1.1"] = subtask})
    assert.are.equal("Component", node.subtasks["1.1"].type)
  end)
end)

describe("TimeLog", function()
  it("should create a new TimeLog instance", function()
    local log = models.TimeLog.new(
      "2023-01-01T10:00:00Z",
      "2023-01-01T11:00:00Z",
      "Work notes",
      "Phone call",
      15,
      {"1.1", "1.2"}
    )
    assert.are.equal("2023-01-01T10:00:00Z", log.start_timestamp)
    assert.are.equal("2023-01-01T11:00:00Z", log.end_timestamp)
    assert.are.equal("Work notes", log.notes)
    assert.are.equal("Phone call", log.interruptions)
    assert.are.equal(15, log.interruption_minutes)
    assert.are.same({"1.1", "1.2"}, log.tasks)
  end)

  it("should use defaults for missing parameters", function()
    local log = models.TimeLog.new()
    assert.are.equal(0, log.interruption_minutes)
    assert.are.same({}, log.tasks)
  end)
end)

describe("Project", function()
  it("should create a new Project instance", function()
    local info = models.ProjectInfo.new("proj-1", "Test")
    local project = models.Project.new(info, {}, {}, {}, {"tag1"})
    assert.are.equal("proj-1", project.project_info.id)
    assert.are.same({"tag1"}, project.tags)
  end)

  it("should create from table data with new estimation format", function()
    local data = {
      project_info = {
        id = "proj-1",
        name = "Test Project"
      },
      structure = {
        ["1"] = {
          type = "Area",
          subtasks = {}
        }
      },
      task_list = {
        ["1"] = {
          name = "Task 1",
          details = "Details",
          estimation = { work_type = "new_work", confidence = "high" },
          notes = "some notes",
          tags = {"tag1"}
        }
      },
      time_log = {
        {
          start_timestamp = "2023-01-01T10:00:00Z",
          end_timestamp = "2023-01-01T11:00:00Z",
          notes = "notes",
          interruptions = "",
          interruption_minutes = 0,
          tasks = {"1"}
        }
      },
      tags = {"project-tag"}
    }

    local project = models.Project.from_table(data)
    assert.are.equal("proj-1", project.project_info.id)
    assert.are.equal("Test Project", project.project_info.name)
    assert.are.equal("Area", project.structure["1"].type)
    assert.are.equal("Task 1", project.task_list["1"].name)
    assert.are.equal("new_work", project.task_list["1"].estimation.work_type)
    assert.are.equal("some notes", project.task_list["1"].notes)
    assert.are.equal("2023-01-01T10:00:00Z", project.time_log[1].start_timestamp)
    assert.are.same({"project-tag"}, project.tags)
  end)

  it("should migrate old string estimation to notes", function()
    local data = {
      project_info = { id = "proj-1", name = "Test" },
      structure = {},
      task_list = {
        ["1"] = {
          name = "Task 1",
          details = "Details",
          estimation = "2h",  -- Old string format
          tags = {}
        }
      },
      time_log = {},
      tags = {}
    }

    local project = models.Project.from_table(data)
    -- Old estimation string should be migrated to notes
    assert.is_nil(project.task_list["1"].estimation)
    assert.are.equal("2h", project.task_list["1"].notes)
  end)
end)
