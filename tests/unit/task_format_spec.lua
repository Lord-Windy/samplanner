-- Unit tests for task text format conversion
-- Run with: luajit tests/unit/task_format_spec.lua

-- Add the lua directory to the package path
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua;./tests/helpers/?.lua"

-- Load mini test framework
require('mini_test')

-- Mock vim global for testing outside Neovim
_G.vim = {
  trim = function(s)
    return s:match("^%s*(.-)%s*$")
  end,
  tbl_contains = function(t, val)
    for _, v in ipairs(t) do
      if v == val then return true end
    end
    return false
  end
}

local models = require('samplanner.domain.models')
local task_format = require('samplanner.formats.task')

describe("Task Format", function()
  describe("task_to_text", function()
    it("should convert a task without estimation (Area/Component)", function()
      local task = models.Task.new("1", "Area Task", "Some details", nil, {"tag1"}, "some notes")

      local text = task_format.task_to_text(task, "Area")

      assert.is_true(text:find("Task: 1") ~= nil)
      assert.is_true(text:find("Name: Area Task") ~= nil)
      assert.is_true(text:find("Details") ~= nil)
      assert.is_true(text:find("Some details") ~= nil)
      assert.is_true(text:find("Notes") ~= nil)
      assert.is_true(text:find("some notes") ~= nil)
      assert.is_true(text:find("Tags") ~= nil)
      assert.is_true(text:find("tag1") ~= nil)
      -- Should NOT have Estimation section
      assert.is_nil(text:find("── Estimation"))
    end)

    it("should include estimation section for Jobs", function()
      local estimation = models.Estimation.new({
        work_type = "bugfix",
        confidence = "high"
      })
      local task = models.Task.new("1.1.1", "Job Task", "Details", estimation, {}, "")

      local text = task_format.task_to_text(task, "Job")

      -- Should have Estimation section
      assert.is_true(text:find("── Estimation") ~= nil)
      assert.is_true(text:find("Type") ~= nil)
      assert.is_true(text:find("%[x%] Bugfix") ~= nil)
      assert.is_true(text:find("%[x%] High") ~= nil)
    end)

    it("should format full estimation template", function()
      local estimation = models.Estimation.new({
        work_type = "new_work",
        assumptions = {"API stable", "No DB changes"},
        effort = {
          method = "three_point",
          base_hours = 8,
          buffer_percent = 20,
          buffer_reason = "unknowns",
          total_hours = 10
        },
        confidence = "med",
        schedule = {
          start_date = "2025-01-15",
          target_finish = "2025-01-20",
          milestones = {{ name = "Design", date = "2025-01-16" }}
        },
        post_estimate_notes = {
          could_be_smaller = {"Reuse code"},
          could_be_bigger = {"Scope creep"},
          ignored_last_time = {"Testing"}
        }
      })
      local task = models.Task.new("1", "Task", "", estimation, {}, "")

      local text = task_format.task_to_text(task, "Job")

      assert.is_true(text:find("%[x%] New work") ~= nil)
      assert.is_true(text:find("API stable") ~= nil)
      assert.is_true(text:find("No DB changes") ~= nil)
      assert.is_true(text:find("%[x%] 3%-point") ~= nil)
      assert.is_true(text:find("Base effort: 8h") ~= nil)
      assert.is_true(text:find("Buffer: 20%%") ~= nil)
      assert.is_true(text:find("unknowns") ~= nil)
      assert.is_true(text:find("Total: 10h") ~= nil)
      assert.is_true(text:find("%[x%] Med") ~= nil)
      assert.is_true(text:find("Start: 2025%-01%-15") ~= nil)
      assert.is_true(text:find("Target finish: 2025%-01%-20") ~= nil)
      assert.is_true(text:find("Design — 2025%-01%-16") ~= nil)
      assert.is_true(text:find("Reuse code") ~= nil)
      assert.is_true(text:find("Scope creep") ~= nil)
      assert.is_true(text:find("Testing") ~= nil)
    end)
  end)

  describe("text_to_task", function()
    it("should parse a simple task without estimation", function()
      local text = [[
── Task: 1 ───────────────────
Name: My Task

── Details ──────────────────────────
Vision / Purpose
Task description here

Goals / Objectives
  - Goal 1
  - Goal 2

Scope / Boundaries
  -

Key Components
  -

Success Metrics / KPIs
  -

Stakeholders
  -

Dependencies / Constraints
  -

Strategic Context


── Notes ────────────────────────────
Some notes

── Tags ─────────────────────────────
bug, feature
]]

      local task = task_format.text_to_task(text, "Area")

      assert.are.equal("1", task.id)
      assert.are.equal("My Task", task.name)
      assert.are.equal("table", type(task.details))
      assert.are.equal("Task description here", task.details.vision_purpose)
      assert.are.same({"Goal 1", "Goal 2"}, task.details.goals_objectives)
      assert.is_nil(task.estimation)
      assert.are.equal("Some notes", task.notes)
      assert.are.same({"bug", "feature"}, task.tags)
    end)

    it("should parse estimation for Jobs", function()
      local text = [[
── Task: 1.1.1 ───────────────────
Name: Job Task

── Details ──────────────────────────

── Estimation ───────────────────────
Type
  [ ] New work   [x] Change   [ ] Bugfix   [ ] Research/Spike

Assumptions
  - API is ready
  - Tests exist

Effort (hours)
Method:
  [x] Similar work   [ ] 3-point   [ ] Gut feel

Estimate:
  - Base effort: 4h
  - Buffer: 15%  (reason: minor unknowns)
  - Total: 5h

Confidence:
  [ ] Low  [x] Med  [ ] High

Schedule
  - Start: 2025-02-01
  - Target finish: 2025-02-03
  - Milestones:
    - Code complete — 2025-02-02

Post-estimate notes
  - What could make this smaller?
    - Already have similar code
  - What could make this bigger?
    - Requirements change
  - What did I ignore / forget last time?
    - Code review time

── Notes ────────────────────────────

── Tags ─────────────────────────────
enhancement
]]

      local task = task_format.text_to_task(text, "Job")

      assert.are.equal("1.1.1", task.id)
      assert.are.equal("Job Task", task.name)
      assert.is_not_nil(task.estimation)

      local est = task.estimation
      assert.are.equal("change", est.work_type)
      assert.are.same({"API is ready", "Tests exist"}, est.assumptions)
      assert.are.equal("similar_work", est.effort.method)
      assert.are.equal(4, est.effort.base_hours)
      assert.are.equal(15, est.effort.buffer_percent)
      assert.are.equal("minor unknowns", est.effort.buffer_reason)
      assert.are.equal(5, est.effort.total_hours)
      assert.are.equal("med", est.confidence)
      assert.are.equal("2025-02-01", est.schedule.start_date)
      assert.are.equal("2025-02-03", est.schedule.target_finish)
      assert.are.equal(1, #est.schedule.milestones)
      assert.are.equal("Code complete", est.schedule.milestones[1].name)
      assert.are.equal("2025-02-02", est.schedule.milestones[1].date)
      assert.are.same({"Already have similar code"}, est.post_estimate_notes.could_be_smaller)
      assert.are.same({"Requirements change"}, est.post_estimate_notes.could_be_bigger)
      assert.are.same({"Code review time"}, est.post_estimate_notes.ignored_last_time)
      assert.are.same({"enhancement"}, task.tags)
    end)

    it("should round-trip task with estimation", function()
      local original_est = models.Estimation.new({
        work_type = "bugfix",
        assumptions = {"Bug is reproducible"},
        effort = {
          method = "gut_feel",
          base_hours = 2,
          buffer_percent = 50,
          buffer_reason = "debugging unknowns",
          total_hours = 3
        },
        confidence = "low",
        schedule = {
          start_date = "2025-03-01",
          target_finish = "2025-03-01",
          milestones = {}
        },
        post_estimate_notes = {
          could_be_smaller = {},
          could_be_bigger = {"Root cause unclear"},
          ignored_last_time = {}
        }
      })

      -- For Job type, create JobDetails object
      local original_job_details = models.JobDetails.new({
        context_why = "Bug is causing user complaints",
        outcome_dod = {"Bug fixed", "Tests passing"},
        scope_in = {"Fix root cause"},
        scope_out = {},
        requirements_constraints = {"No API changes"},
        dependencies = {},
        approach = {"Debug", "Fix", "Test"},
        risks = {"Root cause unclear"},
        validation_test_plan = {"Unit tests", "Manual verification"}
      })

      local original = models.Task.new("2.1", "Fix Bug", original_job_details, original_est, {"urgent"}, "Check logs first")

      -- Convert to text
      local text = task_format.task_to_text(original, "Job")

      -- Parse back
      local parsed = task_format.text_to_task(text, "Job")

      assert.are.equal(original.id, parsed.id)
      assert.are.equal(original.name, parsed.name)

      -- For Job type, details is a JobDetails object
      assert.are.equal("table", type(parsed.details))
      assert.are.equal(original_job_details.context_why, parsed.details.context_why)
      assert.are.same(original_job_details.outcome_dod, parsed.details.outcome_dod)
      assert.are.same(original_job_details.scope_in, parsed.details.scope_in)
      assert.are.same(original_job_details.approach, parsed.details.approach)

      assert.are.equal(original.notes, parsed.notes)
      assert.are.same(original.tags, parsed.tags)

      assert.are.equal(original_est.work_type, parsed.estimation.work_type)
      assert.are.same(original_est.assumptions, parsed.estimation.assumptions)
      assert.are.equal(original_est.effort.method, parsed.estimation.effort.method)
      assert.are.equal(original_est.effort.base_hours, parsed.estimation.effort.base_hours)
      assert.are.equal(original_est.confidence, parsed.estimation.confidence)
      assert.are.equal(original_est.schedule.start_date, parsed.estimation.schedule.start_date)
    end)
  end)

  describe("Job completion tracking", function()
    it("should format uncompleted job with empty checkbox", function()
      local job_details = models.JobDetails.new({
        context_why = "Test job",
        completed = false
      })
      local task = models.Task.new("1", "Job Task", job_details, nil, {}, "")

      local text = task_format.task_to_text(task, "Job")

      assert.is_true(text:find("%[ %] Completed") ~= nil)
    end)

    it("should format completed job with checked checkbox", function()
      local job_details = models.JobDetails.new({
        context_why = "Test job",
        completed = true
      })
      local task = models.Task.new("1", "Job Task", job_details, nil, {}, "")

      local text = task_format.task_to_text(task, "Job")

      assert.is_true(text:find("%[x%] Completed") ~= nil)
    end)

    it("should parse uncompleted job from text", function()
      local text = [[
── Task: 1 ───────────────────
Name: Job Task

── Details ──────────────────────────
Context / Why
Test job

[ ] Completed

Outcome / Definition of Done
  -

Scope
  In scope:
    -
  Out of scope:
    -

Requirements / Constraints
  -

Dependencies
  -

Approach (brief plan)
  -

Risks
  -

Validation / Test Plan
  -

── Notes ────────────────────────────

── Tags ─────────────────────────────
]]

      local task = task_format.text_to_task(text, "Job")

      assert.are.equal("table", type(task.details))
      assert.is_false(task.details.completed)
    end)

    it("should parse completed job from text", function()
      local text = [[
── Task: 1 ───────────────────
Name: Job Task

── Details ──────────────────────────
Context / Why
Test job

[x] Completed

Outcome / Definition of Done
  -

Scope
  In scope:
    -
  Out of scope:
    -

Requirements / Constraints
  -

Dependencies
  -

Approach (brief plan)
  -

Risks
  -

Validation / Test Plan
  -

── Notes ────────────────────────────

── Tags ─────────────────────────────
]]

      local task = task_format.text_to_task(text, "Job")

      assert.are.equal("table", type(task.details))
      assert.is_true(task.details.completed)
    end)

    it("should roundtrip completed status", function()
      local job_details = models.JobDetails.new({
        context_why = "Completed job",
        outcome_dod = {"Done"},
        completed = true
      })
      local original = models.Task.new("1", "Job Task", job_details, nil, {}, "")

      local text = task_format.task_to_text(original, "Job")
      local parsed = task_format.text_to_task(text, "Job")

      assert.are.equal("table", type(parsed.details))
      assert.is_true(parsed.details.completed)
      assert.are.equal("Completed job", parsed.details.context_why)
      assert.are.same({"Done"}, parsed.details.outcome_dod)
    end)

    it("should roundtrip uncompleted status", function()
      local job_details = models.JobDetails.new({
        context_why = "Incomplete job",
        completed = false
      })
      local original = models.Task.new("1", "Job Task", job_details, nil, {}, "")

      local text = task_format.task_to_text(original, "Job")
      local parsed = task_format.text_to_task(text, "Job")

      assert.are.equal("table", type(parsed.details))
      assert.is_false(parsed.details.completed)
      assert.are.equal("Incomplete job", parsed.details.context_why)
    end)
  end)
end)
