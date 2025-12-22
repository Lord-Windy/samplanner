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
      -- First save a project
      local info = models.ProjectInfo.new("proj-1", "TestProject")
      local task = models.Task.new("1", "Task 1", "Details", "1h", {"tag1"})
      local project = models.Project.new(info, {}, {["1"] = task}, {}, {"project-tag"})
      
      file_storage.save(project, test_dir)
      
      -- Now load it
      local loaded_project, err = file_storage.load("TestProject", test_dir)
      
      assert.is_nil(err)
      assert.is_not_nil(loaded_project)
      assert.are.equal("proj-1", loaded_project.project_info.id)
      assert.are.equal("TestProject", loaded_project.project_info.name)
      assert.are.equal("Task 1", loaded_project.task_list["1"].name)
      assert.are.same({"project-tag"}, loaded_project.tags)
    end)
    
    it("should return error if file doesn't exist", function()
      local loaded_project, err = file_storage.load("NonExistent", test_dir)
      
      assert.is_nil(loaded_project)
      assert.is_not_nil(err)
      assert.is_true(string.match(err, "Failed to open file") ~= nil)
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
