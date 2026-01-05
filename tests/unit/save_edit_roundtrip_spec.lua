-- Test that modifications to task/session data persist correctly when saving to JSON
local models = require('samplanner.domain.models')

describe("Save and Edit Round-trip", function()
  local test_file = "/tmp/samplanner_roundtrip_test.json"

  -- Clean up before and after tests
  local function cleanup()
    os.remove(test_file)
  end

  before_each(cleanup)
  after_each(cleanup)

  describe("JobDetails field editing", function()
    it("should persist additions to string fields", function()
      -- Create initial project with old array format
      local initial_data = {
        project_info = { id = "test-1", name = "Test Project" },
        structure = {
          ["1"] = { type = "Area", subtasks = {
            ["1.1"] = { type = "Job", subtasks = {} }
          }}
        },
        task_list = {
          ["1.1"] = {
            name = "Test Job",
            details = {
              context_why = "Initial context",
              outcome_dod = {"Item 1", "Item 2"},  -- Old array format
              approach = {"Step 1", "Step 2"},
              risks = {"Risk 1"}
            },
            tags = {}
          }
        },
        time_log = {},
        tags = {}
      }

      -- Save initial data
      local file = io.open(test_file, "w")
      file:write(vim.json.encode(initial_data))
      file:close()

      -- Load the project (should auto-convert arrays to strings)
      local loaded_file = io.open(test_file, "r")
      local loaded_json = loaded_file:read("*all")
      loaded_file:close()
      local loaded_data = vim.json.decode(loaded_json)
      local project = models.Project.from_table(loaded_data)

      -- Verify auto-conversion happened
      local task = project.task_list["1.1"]
      assert.are.equal("- Item 1\n- Item 2", task.details.outcome_dod)
      assert.are.equal("- Step 1\n- Step 2", task.details.approach)

      -- Simulate user editing: add new items to outcome_dod
      task.details.outcome_dod = task.details.outcome_dod .. "\n- Item 3\n- Item 4"

      -- Add a completely new risk
      task.details.risks = task.details.risks .. "\n- Risk 2\n- Risk 3"

      -- Update context with paragraph
      task.details.context_why = task.details.context_why .. "\n\nAdditional context paragraph explaining more details."

      -- Convert project back to table for saving
      local save_data = {
        project_info = {
          id = project.project_info.id,
          name = project.project_info.name
        },
        structure = loaded_data.structure,
        task_list = {
          ["1.1"] = {
            name = task.name,
            details = {
              context_why = task.details.context_why,
              outcome_dod = task.details.outcome_dod,
              scope_in = task.details.scope_in,
              scope_out = task.details.scope_out,
              requirements_constraints = task.details.requirements_constraints,
              dependencies = task.details.dependencies,
              approach = task.details.approach,
              risks = task.details.risks,
              validation_test_plan = task.details.validation_test_plan,
              completed = task.details.completed
            },
            tags = task.tags,
            notes = task.notes
          }
        },
        time_log = {},
        tags = {}
      }

      -- Save modified data
      local save_file = io.open(test_file, "w")
      save_file:write(vim.json.encode(save_data))
      save_file:close()

      -- Re-load and verify changes persisted
      local reload_file = io.open(test_file, "r")
      local reload_json = reload_file:read("*all")
      reload_file:close()
      local reload_data = vim.json.decode(reload_json)
      local reloaded_project = models.Project.from_table(reload_data)

      local reloaded_task = reloaded_project.task_list["1.1"]

      -- Verify the additions are present
      assert.are.equal("- Item 1\n- Item 2\n- Item 3\n- Item 4", reloaded_task.details.outcome_dod)
      assert.are.equal("- Risk 1\n- Risk 2\n- Risk 3", reloaded_task.details.risks)
      assert.is_truthy(reloaded_task.details.context_why:match("Additional context paragraph"))

      -- Verify the JSON actually has string format (not arrays)
      assert.are.equal("string", type(reload_data.task_list["1.1"].details.outcome_dod))
      assert.are.equal("string", type(reload_data.task_list["1.1"].details.risks))
    end)
  end)

  describe("TimeLog field editing", function()
    it("should persist additions to time log string fields", function()
      -- Create initial project with old array format in time log
      local initial_data = {
        project_info = { id = "test-1", name = "Test Project" },
        structure = {},
        task_list = {},
        time_log = {
          {
            start_timestamp = "2025-01-01T09:00:00Z",
            end_timestamp = "2025-01-01T10:00:00Z",
            notes = "Initial notes",
            interruptions = "",
            interruption_minutes = 0,
            tasks = {"1.1", "1.2"},
            session_type = "coding",
            planned_duration_minutes = 60,
            focus_rating = 4,
            energy_level = { start = 4, ["end"] = 3 },
            context_switches = 1,
            defects = {
              found = {"Bug 1"},  -- Old array format
              fixed = {"Bug 2"}
            },
            deliverables = {"Feature A"},
            blockers = {"Blocker 1"},
            retrospective = {
              what_went_well = {"Good thing 1"},
              what_needs_improvement = {"Bad thing 1"},
              lessons_learned = {"Lesson 1"}
            }
          }
        },
        tags = {}
      }

      -- Save initial data
      local file = io.open(test_file, "w")
      file:write(vim.json.encode(initial_data))
      file:close()

      -- Load the project (should auto-convert arrays to strings)
      local loaded_file = io.open(test_file, "r")
      local loaded_json = loaded_file:read("*all")
      loaded_file:close()
      local loaded_data = vim.json.decode(loaded_json)
      local project = models.Project.from_table(loaded_data)

      -- Verify auto-conversion happened
      local log = project.time_log[1]
      assert.are.equal("- Bug 1", log.defects.found)
      assert.are.equal("- Feature A", log.deliverables)

      -- Simulate user editing: add new items
      log.defects.found = log.defects.found .. "\n- Bug 3\n- Bug 4"
      log.deliverables = log.deliverables .. "\n- Feature B\n- Feature C"
      log.retrospective.what_went_well = log.retrospective.what_went_well .. "\n- Good thing 2"

      -- Convert project back to table for saving
      local save_data = {
        project_info = {
          id = project.project_info.id,
          name = project.project_info.name
        },
        structure = {},
        task_list = {},
        time_log = {
          {
            start_timestamp = log.start_timestamp,
            end_timestamp = log.end_timestamp,
            notes = log.notes,
            interruptions = log.interruptions,
            interruption_minutes = log.interruption_minutes,
            tasks = log.tasks,
            session_type = log.session_type,
            planned_duration_minutes = log.planned_duration_minutes,
            focus_rating = log.focus_rating,
            energy_level = log.energy_level,
            context_switches = log.context_switches,
            defects = log.defects,
            deliverables = log.deliverables,
            blockers = log.blockers,
            retrospective = log.retrospective
          }
        },
        tags = {}
      }

      -- Save modified data
      local save_file = io.open(test_file, "w")
      save_file:write(vim.json.encode(save_data))
      save_file:close()

      -- Re-load and verify changes persisted
      local reload_file = io.open(test_file, "r")
      local reload_json = reload_file:read("*all")
      reload_file:close()
      local reload_data = vim.json.decode(reload_json)
      local reloaded_project = models.Project.from_table(reload_data)

      local reloaded_log = reloaded_project.time_log[1]

      -- Verify the additions are present
      assert.are.equal("- Bug 1\n- Bug 3\n- Bug 4", reloaded_log.defects.found)
      assert.are.equal("- Feature A\n- Feature B\n- Feature C", reloaded_log.deliverables)
      assert.are.equal("- Good thing 1\n- Good thing 2", reloaded_log.retrospective.what_went_well)

      -- Verify the JSON actually has string format (not arrays)
      assert.are.equal("string", type(reload_data.time_log[1].defects.found))
      assert.are.equal("string", type(reload_data.time_log[1].deliverables))

      -- Verify tasks array is still an array
      assert.are.equal("table", type(reload_data.time_log[1].tasks))
      assert.are.same({"1.1", "1.2"}, reload_data.time_log[1].tasks)
    end)
  end)

  describe("Mixed edits with paragraphs", function()
    it("should support multi-line paragraphs within items", function()
      -- Create initial data
      local initial_data = {
        project_info = { id = "test-1", name = "Test Project" },
        structure = {
          ["1"] = { type = "Job", subtasks = {} }
        },
        task_list = {
          ["1"] = {
            name = "Test Job",
            details = {
              context_why = "Short context",
              outcome_dod = "- Simple item",
              approach = "",
              risks = "",
              scope_in = "",
              scope_out = "",
              requirements_constraints = "",
              dependencies = "",
              validation_test_plan = "",
              completed = false
            },
            tags = {}
          }
        },
        time_log = {},
        tags = {}
      }

      -- Save initial data
      local file = io.open(test_file, "w")
      file:write(vim.json.encode(initial_data))
      file:close()

      -- Load
      local loaded_file = io.open(test_file, "r")
      local loaded_data = vim.json.decode(loaded_file:read("*all"))
      loaded_file:close()
      local project = models.Project.from_table(loaded_data)
      local task = project.task_list["1"]

      -- Edit with multi-line content (simulating what a user might type)
      task.details.outcome_dod = [[- Simple item
- Complex item with multiple lines:
  This is a paragraph explaining the complex item.
  It spans multiple lines and provides detail.
- Another item]]

      task.details.approach = [[- Step 1: Initial setup

  Some detailed explanation about step 1 that spans
  multiple lines and provides context.

- Step 2: Implementation

  More details here.]]

      -- Save
      local save_data = {
        project_info = { id = project.project_info.id, name = project.project_info.name },
        structure = loaded_data.structure,
        task_list = {
          ["1"] = {
            name = task.name,
            details = {
              context_why = task.details.context_why,
              outcome_dod = task.details.outcome_dod,
              scope_in = task.details.scope_in,
              scope_out = task.details.scope_out,
              requirements_constraints = task.details.requirements_constraints,
              dependencies = task.details.dependencies,
              approach = task.details.approach,
              risks = task.details.risks,
              validation_test_plan = task.details.validation_test_plan,
              completed = task.details.completed
            },
            tags = task.tags
          }
        },
        time_log = {},
        tags = {}
      }

      local save_file = io.open(test_file, "w")
      save_file:write(vim.json.encode(save_data))
      save_file:close()

      -- Reload and verify
      local reload_file = io.open(test_file, "r")
      local reload_data = vim.json.decode(reload_file:read("*all"))
      reload_file:close()
      local reloaded_project = models.Project.from_table(reload_data)
      local reloaded_task = reloaded_project.task_list["1"]

      -- Verify multi-line content is preserved
      assert.is_truthy(reloaded_task.details.outcome_dod:match("Complex item with multiple lines"))
      assert.is_truthy(reloaded_task.details.outcome_dod:match("This is a paragraph"))
      assert.is_truthy(reloaded_task.details.approach:match("Step 1: Initial setup"))
      assert.is_truthy(reloaded_task.details.approach:match("Some detailed explanation"))

      print("\n=== Saved outcome_dod ===")
      print(reloaded_task.details.outcome_dod)
      print("\n=== Saved approach ===")
      print(reloaded_task.details.approach)
    end)
  end)
end)

print("\nRun this test with: lua tests/unit/save_edit_roundtrip_spec.lua")
print("This test verifies that edits to task/session fields persist correctly when saving to JSON")
