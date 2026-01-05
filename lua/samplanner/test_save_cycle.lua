-- Diagnostic test for save/load cycle
-- Run in Neovim with: :lua require('samplanner.test_save_cycle').run()

local models = require('samplanner.domain.models')
local file_storage = require('samplanner.ports.file_storage')

local M = {}

function M.run()
  print("\n=== Testing Save/Edit/Load Cycle ===\n")

  local test_dir = vim.fn.stdpath('data') .. '/samplanner_test'
  vim.fn.mkdir(test_dir, 'p')

  -- Step 1: Create initial project
  print("1. Creating initial project...")
  local project_info = models.ProjectInfo.new("test-1", "DiagnosticTest")
  local project = models.Project.new(project_info, {}, {}, {}, {}, "")

  -- Add structure
  project.structure["1"] = models.StructureNode.new("1", "Job", {})

  -- Add task with initial data using new string format
  local job_details = models.JobDetails.new({
    context_why = "Initial context",
    outcome_dod = "- Item 1\n- Item 2",  -- New string format
    approach = "- Step 1",
    risks = "",
    scope_in = "",
    scope_out = "",
    requirements_constraints = "",
    dependencies = "",
    validation_test_plan = "",
    completed = false
  })

  local task = models.Task.new("1", "Diagnostic Task", job_details, nil, {}, "")
  project.task_list["1"] = task

  print("   Initial outcome_dod: '" .. task.details.outcome_dod .. "'")
  print("   Initial approach: '" .. task.details.approach .. "'")

  -- Step 2: Save
  print("\n2. Saving initial project...")
  local ok, err = file_storage.save(project, test_dir)
  if not ok then
    print("   ERROR: Failed to save: " .. tostring(err))
    return false
  end
  print("   ✓ Saved to " .. test_dir .. "/DiagnosticTest.json")

  -- Step 3: Load
  print("\n3. Loading project...")
  local loaded_project, warn = file_storage.load("DiagnosticTest", test_dir)
  if warn then
    print("   Warning: " .. warn)
  end

  local loaded_task = loaded_project.task_list["1"]
  print("   Loaded outcome_dod: '" .. loaded_task.details.outcome_dod .. "'")
  print("   Loaded approach: '" .. loaded_task.details.approach .. "'")

  -- Step 4: Edit
  print("\n4. Simulating user edit...")
  print("   Adding '\\n- Item 3' to outcome_dod")
  loaded_task.details.outcome_dod = loaded_task.details.outcome_dod .. "\n- Item 3"

  print("   Adding '\\n- Step 2\\n- Step 3' to approach")
  loaded_task.details.approach = loaded_task.details.approach .. "\n- Step 2\n- Step 3"

  print("   Modified outcome_dod: '" .. loaded_task.details.outcome_dod .. "'")
  print("   Modified approach: '" .. loaded_task.details.approach .. "'")

  -- Step 5: Save edited version
  print("\n5. Saving edited project...")
  ok, err = file_storage.save(loaded_project, test_dir)
  if not ok then
    print("   ERROR: Failed to save: " .. tostring(err))
    return false
  end
  print("   ✓ Saved edits")

  -- Step 6: Load again
  print("\n6. Loading project again to verify persistence...")
  local final_project, warn2 = file_storage.load("DiagnosticTest", test_dir)
  if warn2 then
    print("   Warning: " .. warn2)
  end

  local final_task = final_project.task_list["1"]
  print("   Final outcome_dod: '" .. final_task.details.outcome_dod .. "'")
  print("   Final approach: '" .. final_task.details.approach .. "'")

  -- Step 7: Verify
  print("\n7. Verification...")
  local expected_outcome = "- Item 1\n- Item 2\n- Item 3"
  local expected_approach = "- Step 1\n- Step 2\n- Step 3"

  local success = true

  if final_task.details.outcome_dod == expected_outcome then
    print("   ✓ outcome_dod matches expected")
  else
    print("   ✗ outcome_dod MISMATCH!")
    print("     Expected: '" .. expected_outcome .. "'")
    print("     Got:      '" .. final_task.details.outcome_dod .. "'")
    success = false
  end

  if final_task.details.approach == expected_approach then
    print("   ✓ approach matches expected")
  else
    print("   ✗ approach MISMATCH!")
    print("     Expected: '" .. expected_approach .. "'")
    print("     Got:      '" .. final_task.details.approach .. "'")
    success = false
  end

  -- Step 8: Check raw JSON
  print("\n8. Checking raw JSON...")
  local json_path = test_dir .. "/DiagnosticTest.json"
  local file = io.open(json_path, "r")
  if file then
    local content = file:read("*all")
    file:close()

    local data = vim.fn.json_decode(content)
    local outcome_type = type(data.task_list["1"].details.outcome_dod)
    local approach_type = type(data.task_list["1"].details.approach)

    print("   Raw JSON outcome_dod type: " .. outcome_type)
    print("   Raw JSON approach type: " .. approach_type)

    if outcome_type == "string" and approach_type == "string" then
      print("   ✓ Fields saved as strings (correct)")
    else
      print("   ✗ Fields not saved as strings!")
      success = false
    end

    print("\n   You can inspect the full JSON at: " .. json_path)
  else
    print("   ✗ Could not read JSON file")
    success = false
  end

  -- Summary
  print("\n=== Test Complete ===")
  if success then
    print("✓ All checks passed! Save/edit/load cycle is working correctly.")
  else
    print("✗ Some checks failed. See above for details.")
    print("\nIf this test passes but your actual edits don't save,")
    print("the issue may be in the buffer editing workflow.")
    print("Check the buffer text format matches what the parser expects.")
  end

  return success
end

return M
