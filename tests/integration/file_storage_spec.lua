-- Integration tests for file storage
-- Run with: luajit tests/integration/file_storage_spec.lua

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
      -- Simple glob implementation for testing
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
      -- Extract filename without extension (:t:r)
      if mods == ":t:r" then
        local filename = path:match("([^/]+)$")
        return filename:match("(.+)%..+$") or filename
      end
      return path
    end
  }
}

local models = require('samplanner.domain.models')
local file_storage = require('samplanner.ports.file_storage')

describe("FileStorage", function()
  local test_dir = "./tests/tmp"
  
  before_each(function()
    -- Clean up test directory
    os.execute("rm -rf " .. test_dir)
    os.execute("mkdir -p " .. test_dir)
  end)
  
  after_each(function()
    -- Clean up test directory
    os.execute("rm -rf " .. test_dir)
  end)
  
  describe("save", function()
    it("should save a project to a JSON file", function()
      local info = models.ProjectInfo.new("proj-1", "TestProject")
      local project = models.Project.new(info, {}, {}, {}, {})
      
      local success, err = file_storage.save(project, test_dir)
      
      assert.is_true(success)
      assert.is_nil(err)
      
      -- Check file exists
      local file = io.open(test_dir .. "/TestProject.json", "r")
      assert.is_not_nil(file)
      if file then
        file:close()
      end
    end)
    
    it("should create directory if it doesn't exist", function()
      local nested_dir = test_dir .. "/nested/path"
      local info = models.ProjectInfo.new("proj-1", "TestProject")
      local project = models.Project.new(info, {}, {}, {}, {})
      
      local success, err = file_storage.save(project, nested_dir)
      
      assert.is_true(success)
      assert.is_nil(err)
    end)
  end)
  
  describe("load", function()
    it("should load a project from a JSON file", function()
      -- First save a project with no estimation
      local info = models.ProjectInfo.new("proj-1", "TestProject")
      local area_details = models.AreaDetails.new({vision_purpose = "Test area"})
      local task = models.Task.new("1", "Task 1", area_details, nil, {"tag1"}, "some notes")
      local structure = {["1"] = models.StructureNode.new("1", "Area", {})}
      local project = models.Project.new(info, structure, {["1"] = task}, {}, {"project-tag"})

      file_storage.save(project, test_dir)

      -- Now load it
      local loaded_project, err = file_storage.load("TestProject", test_dir)

      assert.is_nil(err)
      assert.is_not_nil(loaded_project)
      assert.are.equal("proj-1", loaded_project.project_info.id)
      assert.are.equal("TestProject", loaded_project.project_info.name)
      assert.are.equal("Task 1", loaded_project.task_list["1"].name)
      assert.are.equal("Test area", loaded_project.task_list["1"].details.vision_purpose)
      assert.are.equal("some notes", loaded_project.task_list["1"].notes)
      assert.is_nil(loaded_project.task_list["1"].estimation)
      assert.are.same({"project-tag"}, loaded_project.tags)
    end)

    it("should create new project if file doesn't exist", function()
      local loaded_project, warning = file_storage.load("NonExistent", test_dir)

      assert.is_not_nil(loaded_project)
      assert.is_not_nil(warning)
      assert.is_true(string.match(warning, "file did not exist") ~= nil)
      assert.are.equal("NonExistent", loaded_project.project_info.name)
      assert.are.equal("", loaded_project.notes)
    end)

    it("should recover data when JSON parse fails", function()
      -- Write invalid JSON to file
      local filepath = test_dir .. "/BadJson.json"
      local file = io.open(filepath, "w")
      file:write("{ invalid json content here }")
      file:close()

      local loaded_project, warning = file_storage.load("BadJson", test_dir)

      assert.is_not_nil(loaded_project)
      assert.is_not_nil(warning)
      assert.is_true(string.match(warning, "JSON parse failed") ~= nil)
      assert.are.equal("BadJson", loaded_project.project_info.name)
      -- Raw content should be preserved in notes
      assert.is_true(string.match(loaded_project.notes, "RECOVERED DATA") ~= nil)
      assert.is_true(string.match(loaded_project.notes, "invalid json content") ~= nil)
    end)

    it("should create new project if file is empty", function()
      -- Create empty file
      local filepath = test_dir .. "/EmptyFile.json"
      local file = io.open(filepath, "w")
      file:write("")
      file:close()

      local loaded_project, warning = file_storage.load("EmptyFile", test_dir)

      assert.is_not_nil(loaded_project)
      assert.is_not_nil(warning)
      assert.is_true(string.match(warning, "file was empty") ~= nil)
      assert.are.equal("EmptyFile", loaded_project.project_info.name)
    end)

    it("should save and load structured estimation for Jobs", function()
      local info = models.ProjectInfo.new("proj-1", "EstimationTest")

      -- Create a structured estimation
      local estimation = models.Estimation.new({
        work_type = "new_work",
        assumptions = {"API is stable", "No DB changes"},
        effort = {
          method = "three_point",
          base_hours = 8,
          buffer_percent = 25,
          buffer_reason = "unknowns in requirements",
          total_hours = 10
        },
        confidence = "med",
        schedule = {
          start_date = "2025-01-15",
          target_finish = "2025-01-20",
          milestones = {
            { name = "Design complete", date = "2025-01-16" },
            { name = "Implementation done", date = "2025-01-19" }
          }
        },
        post_estimate_notes = {
          could_be_smaller = {"Reuse existing component"},
          could_be_bigger = {"API changes", "Scope creep"},
          ignored_last_time = {"Testing time"}
        }
      })

      -- Create structured details for Job type
      local job_details = models.JobDetails.new({
        context_why = "Users need this feature",
        outcome_dod = {"Feature implemented", "Tests pass"},
        scope_in = {"Core functionality"},
        scope_out = {"Advanced options"},
        requirements_constraints = {"Must be backwards compatible"},
        dependencies = {"API v2"},
        approach = {"Design", "Implement", "Test"},
        risks = {"API changes"},
        validation_test_plan = {"Unit tests", "Integration tests"}
      })

      local task = models.Task.new("1.1.1", "Implement Feature", job_details, estimation, {"feature"}, "additional notes")
      local node = models.StructureNode.new("1.1.1", "Job", {})
      local project = models.Project.new(info, {["1.1.1"] = node}, {["1.1.1"] = task}, {}, {})

      -- Save
      local success, err = file_storage.save(project, test_dir)
      assert.is_true(success)
      assert.is_nil(err)

      -- Load
      local loaded, load_err = file_storage.load("EstimationTest", test_dir)
      assert.is_nil(load_err)
      assert.is_not_nil(loaded)

      -- Verify estimation was preserved
      local loaded_task = loaded.task_list["1.1.1"]
      assert.is_not_nil(loaded_task)
      assert.is_not_nil(loaded_task.estimation)

      local est = loaded_task.estimation
      assert.are.equal("new_work", est.work_type)
      assert.are.same({"API is stable", "No DB changes"}, est.assumptions)
      assert.are.equal("three_point", est.effort.method)
      assert.are.equal(8, est.effort.base_hours)
      assert.are.equal(25, est.effort.buffer_percent)
      assert.are.equal("unknowns in requirements", est.effort.buffer_reason)
      assert.are.equal(10, est.effort.total_hours)
      assert.are.equal("med", est.confidence)
      assert.are.equal("2025-01-15", est.schedule.start_date)
      assert.are.equal("2025-01-20", est.schedule.target_finish)
      assert.are.equal(2, #est.schedule.milestones)
      assert.are.equal("Design complete", est.schedule.milestones[1].name)
      assert.are.equal("2025-01-16", est.schedule.milestones[1].date)
      assert.are.same({"Reuse existing component"}, est.post_estimate_notes.could_be_smaller)
      assert.are.same({"API changes", "Scope creep"}, est.post_estimate_notes.could_be_bigger)
      assert.are.same({"Testing time"}, est.post_estimate_notes.ignored_last_time)

      -- Verify JobDetails was preserved
      assert.are.equal("table", type(loaded_task.details))
      assert.are.equal("Users need this feature", loaded_task.details.context_why)
      assert.are.same({"Feature implemented", "Tests pass"}, loaded_task.details.outcome_dod)

      assert.are.equal("additional notes", loaded_task.notes)
    end)

    it("should migrate old string estimation and details to notes on load", function()
      -- Manually create a JSON file with old format
      local old_format_json = [[{
        "project_info": {"id": "proj-1", "name": "MigrationTest"},
        "structure": {"1": {"type": "Job"}},
        "task_list": {
          "1": {
            "name": "Old Task",
            "details": "Details",
            "estimation": "2 hours",
            "tags": ["bug"]
          }
        },
        "time_log": [],
        "tags": []
      }]]

      -- Write the old format file directly
      local file = io.open(test_dir .. "/MigrationTest.json", "w")
      file:write(old_format_json)
      file:close()

      -- Load it
      local loaded, err = file_storage.load("MigrationTest", test_dir)

      assert.is_nil(err)
      assert.is_not_nil(loaded)

      local task = loaded.task_list["1"]
      assert.is_not_nil(task)
      assert.are.equal("Old Task", task.name)
      -- Old string estimation should be migrated to notes
      assert.is_nil(task.estimation)
      -- Both old string details and estimation should be migrated to notes
      assert.is_true(task.notes:find("Migrated details") ~= nil)
      assert.is_true(task.notes:find("Details") ~= nil)
      assert.is_true(task.notes:find("2 hours") ~= nil)
      -- Details should now be an empty JobDetails object
      assert.are.equal("table", type(task.details))
      assert.is_true(task.details:is_empty())
    end)

    it("should preserve empty estimation as nil", function()
      local info = models.ProjectInfo.new("proj-1", "NilEstTest")
      local task = models.Task.new("1", "Task", "", nil, {}, "")
      local project = models.Project.new(info, {}, {["1"] = task}, {}, {})

      file_storage.save(project, test_dir)
      local loaded, _ = file_storage.load("NilEstTest", test_dir)

      assert.is_nil(loaded.task_list["1"].estimation)
    end)

    it("should save and load project notes", function()
      local info = models.ProjectInfo.new("proj-1", "NotesTest")
      local project = models.Project.new(info, {}, {}, {}, {}, "Project-level notes here")

      file_storage.save(project, test_dir)
      local loaded, _ = file_storage.load("NotesTest", test_dir)

      assert.are.equal("Project-level notes here", loaded.notes)
    end)

    it("should not include empty project notes in JSON", function()
      local info = models.ProjectInfo.new("proj-1", "NoNotesTest")
      local project = models.Project.new(info, {}, {}, {}, {}, "")

      file_storage.save(project, test_dir)

      -- Read the raw JSON to verify notes is not included
      local file = io.open(test_dir .. "/NoNotesTest.json", "r")
      local content = file:read("*all")
      file:close()

      -- notes should not appear in JSON when empty
      assert.is_nil(string.match(content, '"notes"'))

      -- But load should still work
      local loaded, _ = file_storage.load("NoNotesTest", test_dir)
      assert.are.equal("", loaded.notes)
    end)
  end)
  
  describe("list_projects", function()
    it("should list all projects in directory", function()
      -- Create multiple projects
      local info1 = models.ProjectInfo.new("proj-1", "ListTest1")
      local info2 = models.ProjectInfo.new("proj-2", "ListTest2")
      local project1 = models.Project.new(info1, {}, {}, {}, {})
      local project2 = models.Project.new(info2, {}, {}, {}, {})
      
      file_storage.save(project1, test_dir)
      file_storage.save(project2, test_dir)
      
      local projects = file_storage.list_projects(test_dir)
      
      -- Check that our projects exist (may be more files from other tests)
      local found1, found2 = false, false
      for _, name in ipairs(projects) do
        if name == "ListTest1" then found1 = true end
        if name == "ListTest2" then found2 = true end
      end
      assert.is_true(found1)
      assert.is_true(found2)
    end)
    
    it("should return empty list for non-existent directory", function()
      local projects = file_storage.list_projects(test_dir .. "/nonexistent")
      assert.are.equal(0, #projects)
    end)
  end)
end)
