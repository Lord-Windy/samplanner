-- Test array to string migration
local helpers = require('samplanner.migrations.array_string_helpers')
local models = require('samplanner.domain.models')

describe("Array/String Migration Helpers", function()
  describe("array_to_text", function()
    it("should convert empty array to empty string", function()
      assert.are.equal("", helpers.array_to_text({}))
    end)

    it("should convert single item array", function()
      assert.are.equal("- item 1", helpers.array_to_text({"item 1"}))
    end)

    it("should convert multiple item array", function()
      local result = helpers.array_to_text({"item 1", "item 2", "item 3"})
      assert.are.equal("- item 1\n- item 2\n- item 3", result)
    end)

    it("should skip empty items", function()
      local result = helpers.array_to_text({"item 1", "", "item 2"})
      assert.are.equal("- item 1\n- item 2", result)
    end)
  end)

  describe("text_to_array", function()
    it("should convert empty string to empty array", function()
      assert.are.same({}, helpers.text_to_array(""))
    end)

    it("should convert single item string", function()
      assert.are.same({"item 1"}, helpers.text_to_array("- item 1"))
    end)

    it("should convert multiple item string", function()
      local result = helpers.text_to_array("- item 1\n- item 2\n- item 3")
      assert.are.same({"item 1", "item 2", "item 3"}, result)
    end)

    it("should handle strings without bullet prefix", function()
      local result = helpers.text_to_array("item 1\nitem 2")
      assert.are.same({"item 1", "item 2"}, result)
    end)

    it("should handle mixed format", function()
      local result = helpers.text_to_array("- item 1\nitem 2\n- item 3")
      assert.are.same({"item 1", "item 2", "item 3"}, result)
    end)
  end)

  describe("Round-trip conversion", function()
    it("should preserve data through array->string->array", function()
      local original = {"item 1", "item 2", "item 3"}
      local as_string = helpers.array_to_text(original)
      local back_to_array = helpers.text_to_array(as_string)
      assert.are.same(original, back_to_array)
    end)
  end)
end)

describe("Model Auto-Migration", function()
  describe("JobDetails", function()
    it("should auto-convert arrays to strings", function()
      local jd = models.JobDetails.new({
        outcome_dod = {"Complete X", "Write tests"},
        approach = {"Step 1", "Step 2", "Step 3"}
      })
      assert.are.equal("- Complete X\n- Write tests", jd.outcome_dod)
      assert.are.equal("- Step 1\n- Step 2\n- Step 3", jd.approach)
    end)

    it("should accept string format directly", function()
      local jd = models.JobDetails.new({
        outcome_dod = "- Complete X\n- Write tests",
        approach = "- Step 1\n- Step 2\n- Step 3"
      })
      assert.are.equal("- Complete X\n- Write tests", jd.outcome_dod)
      assert.are.equal("- Step 1\n- Step 2\n- Step 3", jd.approach)
    end)
  end)

  describe("Estimation", function()
    it("should auto-convert arrays to strings", function()
      local est = models.Estimation.new({
        assumptions = {"Assumption 1", "Assumption 2"},
        post_estimate_notes = {
          could_be_smaller = {"Note 1"},
          could_be_bigger = {"Note 2"},
          ignored_last_time = {"Note 3"}
        }
      })
      assert.are.equal("- Assumption 1\n- Assumption 2", est.assumptions)
      assert.are.equal("- Note 1", est.post_estimate_notes.could_be_smaller)
      assert.are.equal("- Note 2", est.post_estimate_notes.could_be_bigger)
      assert.are.equal("- Note 3", est.post_estimate_notes.ignored_last_time)
    end)
  end)

  describe("TimeLog", function()
    it("should auto-convert arrays to strings but keep tasks as array", function()
      local tl = models.TimeLog.new(
        "", "", "", "", 0,
        {"1.1", "1.2"},  -- tasks array
        "", 0, 0, {start=0, ["end"]=0}, 0,
        {found = {"Bug 1"}, fixed = {"Bug 2"}},
        {"Deliverable 1"},
        {"Blocker 1"},
        {what_went_well = {"Good 1"}, what_needs_improvement = {"Bad 1"}, lessons_learned = {"Lesson 1"}}
      )
      -- Tasks should remain as array
      assert.are.same({"1.1", "1.2"}, tl.tasks)

      -- Other fields should be converted to strings
      assert.are.equal("- Bug 1", tl.defects.found)
      assert.are.equal("- Bug 2", tl.defects.fixed)
      assert.are.equal("- Deliverable 1", tl.deliverables)
      assert.are.equal("- Blocker 1", tl.blockers)
      assert.are.equal("- Good 1", tl.retrospective.what_went_well)
      assert.are.equal("- Bad 1", tl.retrospective.what_needs_improvement)
      assert.are.equal("- Lesson 1", tl.retrospective.lessons_learned)
    end)
  end)
end)

print("Run this test with: lua tests/unit/array_string_migration_spec.lua")
