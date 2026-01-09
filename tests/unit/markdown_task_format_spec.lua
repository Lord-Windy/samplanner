-- Unit tests for Markdown task format conversion
-- Run with: luajit tests/unit/markdown_task_format_spec.lua
--
-- These tests define the expected behavior for the new Markdown format.
-- The format uses:
-- - H1 (#) for task identification: # Task: 1.1.1 - Task Name
-- - H2 (##) for major sections: ## Details, ## Estimation, ## Notes, ## Tags
-- - H3 (###) for sub-sections within Details
-- - GFM-style checkboxes: - [x] or - [ ]

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

describe("Markdown Task Format", function()
  describe("task_to_text output format", function()
    it("should output H1 header with task ID and name", function()
      local task = models.Task.new("1.1", "My Task", "Some details", nil, {}, "")

      local text = task_format.task_to_text(task, "Component")

      -- Should start with H1 containing task ID and name
      assert.is_true(text:find("^# Task: 1%.1 %- My Task") ~= nil,
        "Expected H1 header with task ID and name, got: " .. text:sub(1, 50))
    end)

    it("should output H2 for Details section", function()
      local task = models.Task.new("1", "Task", "Details here", nil, {}, "")

      local text = task_format.task_to_text(task, "Area")

      assert.is_true(text:find("\n## Details\n") ~= nil,
        "Expected '## Details' section header")
    end)

    it("should output H2 for Notes section", function()
      local task = models.Task.new("1", "Task", "", nil, {}, "Some notes")

      local text = task_format.task_to_text(task, "Area")

      assert.is_true(text:find("\n## Notes\n") ~= nil,
        "Expected '## Notes' section header")
    end)

    it("should output H2 for Tags section", function()
      local task = models.Task.new("1", "Task", "", nil, {"tag1", "tag2"}, "")

      local text = task_format.task_to_text(task, "Area")

      assert.is_true(text:find("\n## Tags\n") ~= nil,
        "Expected '## Tags' section header")
    end)

    it("should output H2 for Estimation section for Jobs", function()
      local estimation = models.Estimation.new({
        work_type = "new_work",
        confidence = "med"
      })
      local task = models.Task.new("1.1.1", "Job Task", "", estimation, {}, "")

      local text = task_format.task_to_text(task, "Job")

      assert.is_true(text:find("\n## Estimation\n") ~= nil,
        "Expected '## Estimation' section header for Jobs")
    end)

    it("should NOT output Estimation section for Areas", function()
      local task = models.Task.new("1", "Area Task", "", nil, {}, "")

      local text = task_format.task_to_text(task, "Area")

      assert.is_nil(text:find("## Estimation"),
        "Areas should not have Estimation section")
    end)

    it("should NOT output Estimation section for Components", function()
      local task = models.Task.new("1.1", "Component Task", "", nil, {}, "")

      local text = task_format.task_to_text(task, "Component")

      assert.is_nil(text:find("## Estimation"),
        "Components should not have Estimation section")
    end)
  end)

  describe("Area details formatting", function()
    it("should output H3 for Area sub-sections", function()
      local area_details = models.AreaDetails.new({
        vision_purpose = "Our vision",
        goals_objectives = "- Goal 1\n- Goal 2",
        scope_boundaries = "- In scope item",
      })
      local task = models.Task.new("1", "Area", area_details, nil, {}, "")

      local text = task_format.task_to_text(task, "Area")

      assert.is_true(text:find("\n### Vision / Purpose\n") ~= nil,
        "Expected '### Vision / Purpose' sub-section")
      assert.is_true(text:find("\n### Goals / Objectives\n") ~= nil,
        "Expected '### Goals / Objectives' sub-section")
      assert.is_true(text:find("\n### Scope / Boundaries\n") ~= nil,
        "Expected '### Scope / Boundaries' sub-section")
    end)

    it("should output content directly under H3 headers (no indentation)", function()
      local area_details = models.AreaDetails.new({
        vision_purpose = "Our vision statement here",
        goals_objectives = "- Goal 1\n- Goal 2",
      })
      local task = models.Task.new("1", "Area", area_details, nil, {}, "")

      local text = task_format.task_to_text(task, "Area")

      -- Content should follow header directly, not be indented
      assert.is_true(text:find("### Vision / Purpose\nOur vision statement here") ~= nil,
        "Vision content should directly follow H3 header")
      assert.is_true(text:find("### Goals / Objectives\n%- Goal 1") ~= nil,
        "Goals content should directly follow H3 header")
    end)
  end)

  describe("Component details formatting", function()
    it("should output H3 for Component sub-sections", function()
      local component_details = models.ComponentDetails.new({
        purpose = "Component purpose",
        capabilities = "- Feature 1",
        acceptance_criteria = "- Criteria 1",
      })
      local task = models.Task.new("1.1", "Component", component_details, nil, {}, "")

      local text = task_format.task_to_text(task, "Component")

      assert.is_true(text:find("\n### Purpose / What It Is\n") ~= nil,
        "Expected '### Purpose / What It Is' sub-section")
      assert.is_true(text:find("\n### Capabilities / Features\n") ~= nil,
        "Expected '### Capabilities / Features' sub-section")
      assert.is_true(text:find("\n### Acceptance Criteria\n") ~= nil,
        "Expected '### Acceptance Criteria' sub-section")
    end)
  end)

  describe("Job details formatting", function()
    it("should output H3 for Job sub-sections", function()
      local job_details = models.JobDetails.new({
        context_why = "Why we need this",
        outcome_dod = "- Done when X",
        approach = "- Step 1\n- Step 2",
      })
      local task = models.Task.new("1.1.1", "Job", job_details, nil, {}, "")

      local text = task_format.task_to_text(task, "Job")

      assert.is_true(text:find("\n### Context / Why\n") ~= nil,
        "Expected '### Context / Why' sub-section")
      assert.is_true(text:find("\n### Outcome / Definition of Done\n") ~= nil,
        "Expected '### Outcome / Definition of Done' sub-section")
      assert.is_true(text:find("\n### Approach") ~= nil,
        "Expected '### Approach' sub-section")
    end)

    it("should format completion checkbox as GFM task list item", function()
      local job_details = models.JobDetails.new({
        context_why = "Test",
        completed = false
      })
      local task = models.Task.new("1", "Job", job_details, nil, {}, "")

      local text = task_format.task_to_text(task, "Job")

      -- Should be GFM format: "- [ ] Completed" not "[ ] Completed"
      assert.is_true(text:find("%- %[ %] Completed") ~= nil,
        "Uncompleted job should have '- [ ] Completed'")
    end)

    it("should format checked completion as GFM task list item", function()
      local job_details = models.JobDetails.new({
        context_why = "Test",
        completed = true
      })
      local task = models.Task.new("1", "Job", job_details, nil, {}, "")

      local text = task_format.task_to_text(task, "Job")

      assert.is_true(text:find("%- %[x%] Completed") ~= nil,
        "Completed job should have '- [x] Completed'")
    end)
  end)

  describe("Estimation formatting", function()
    it("should format work type as vertical GFM checkboxes", function()
      local estimation = models.Estimation.new({
        work_type = "new_work",
      })
      local task = models.Task.new("1", "Job", "", estimation, {}, "")

      local text = task_format.task_to_text(task, "Job")

      -- Each option should be on its own line as GFM checkbox
      assert.is_true(text:find("%- %[x%] New work\n") ~= nil,
        "Selected work type should be '- [x] New work'")
      assert.is_true(text:find("%- %[ %] Change\n") ~= nil,
        "Unselected work type should be '- [ ] Change'")
      assert.is_true(text:find("%- %[ %] Bugfix\n") ~= nil,
        "Unselected work type should be '- [ ] Bugfix'")
      assert.is_true(text:find("%- %[ %] Research/Spike") ~= nil,
        "Unselected work type should be '- [ ] Research/Spike'")
    end)

    it("should format confidence as vertical GFM checkboxes", function()
      local estimation = models.Estimation.new({
        confidence = "med",
      })
      local task = models.Task.new("1", "Job", "", estimation, {}, "")

      local text = task_format.task_to_text(task, "Job")

      assert.is_true(text:find("%- %[ %] Low\n") ~= nil,
        "Unselected confidence should be '- [ ] Low'")
      assert.is_true(text:find("%- %[x%] Med\n") ~= nil,
        "Selected confidence should be '- [x] Med'")
      assert.is_true(text:find("%- %[ %] High") ~= nil,
        "Unselected confidence should be '- [ ] High'")
    end)

    it("should format estimation method as vertical GFM checkboxes", function()
      local estimation = models.Estimation.new({
        effort = { method = "three_point" },
      })
      local task = models.Task.new("1", "Job", "", estimation, {}, "")

      local text = task_format.task_to_text(task, "Job")

      assert.is_true(text:find("%- %[ %] Similar work\n") ~= nil,
        "Unselected method should be '- [ ] Similar work'")
      assert.is_true(text:find("%- %[x%] 3%-point\n") ~= nil,
        "Selected method should be '- [x] 3-point'")
      assert.is_true(text:find("%- %[ %] Gut feel") ~= nil,
        "Unselected method should be '- [ ] Gut feel'")
    end)
  end)

  describe("text_to_task parsing", function()
    it("should parse H1 header to extract task ID and name", function()
      local text = [[
# Task: 1.2.3 - My Great Task

## Details

### Vision / Purpose
Some vision

## Notes

## Tags
]]

      local task = task_format.text_to_task(text, "Area")

      assert.are.equal("1.2.3", task.id)
      assert.are.equal("My Great Task", task.name)
    end)

    it("should parse H2 sections correctly", function()
      local text = [[
# Task: 1 - Test Task

## Details

### Vision / Purpose
The vision

## Notes
Some important notes

## Tags
tag1, tag2
]]

      local task = task_format.text_to_task(text, "Area")

      assert.are.equal("Some important notes", task.notes)
      assert.are.same({"tag1", "tag2"}, task.tags)
    end)

    it("should parse Area details from H3 sub-sections", function()
      local text = [[
# Task: 1 - Area Task

## Details

### Vision / Purpose
Our grand vision

### Goals / Objectives
- Goal 1
- Goal 2

### Scope / Boundaries
- In scope

### Key Components
- Component A

### Success Metrics / KPIs
- Metric 1

### Stakeholders
- Team A

### Dependencies / Constraints
- Dependency 1

### Strategic Context
The context

## Notes

## Tags
]]

      local task = task_format.text_to_task(text, "Area")

      assert.are.equal("table", type(task.details))
      assert.are.equal("Our grand vision", task.details.vision_purpose)
      assert.are.equal("- Goal 1\n- Goal 2", task.details.goals_objectives)
      assert.are.equal("- In scope", task.details.scope_boundaries)
      assert.are.equal("- Component A", task.details.key_components)
      assert.are.equal("- Metric 1", task.details.success_metrics)
      assert.are.equal("- Team A", task.details.stakeholders)
      assert.are.equal("- Dependency 1", task.details.dependencies_constraints)
      assert.are.equal("The context", task.details.strategic_context)
    end)

    it("should parse Component details from H3 sub-sections", function()
      local text = [[
# Task: 1.1 - Component Task

## Details

### Purpose / What It Is
The purpose

### Capabilities / Features
- Feature 1
- Feature 2

### Acceptance Criteria
- Criterion 1

### Architecture / Design
- Design note

### Interfaces / Integration Points
- Interface 1

### Quality Attributes
- Quality 1

### Related Components
- Component X

### Other
Other notes

## Notes

## Tags
]]

      local task = task_format.text_to_task(text, "Component")

      assert.are.equal("table", type(task.details))
      assert.are.equal("The purpose", task.details.purpose)
      assert.are.equal("- Feature 1\n- Feature 2", task.details.capabilities)
      assert.are.equal("- Criterion 1", task.details.acceptance_criteria)
      assert.are.equal("- Design note", task.details.architecture_design)
      assert.are.equal("- Interface 1", task.details.interfaces_integration)
      assert.are.equal("- Quality 1", task.details.quality_attributes)
      assert.are.equal("- Component X", task.details.related_components)
      assert.are.equal("Other notes", task.details.other)
    end)

    it("should parse Job details from H3 sub-sections", function()
      local text = [[
# Task: 1.1.1 - Job Task

## Details

### Context / Why
The context

- [ ] Completed

### Outcome / Definition of Done
- Done when X

### Scope
**In scope:**
- Item 1

**Out of scope:**
- Item 2

### Requirements / Constraints
- Requirement 1

### Dependencies
- Dep 1

### Approach (brief plan)
- Step 1

### Risks
- Risk 1

### Validation / Test Plan
- Test 1

## Estimation

### Type
- [x] New work
- [ ] Change
- [ ] Bugfix
- [ ] Research/Spike

### Assumptions
- Assumption 1

### Effort (hours)
**Method:**
- [ ] Similar work
- [x] 3-point
- [ ] Gut feel

**Estimate:**
- Base effort: 8h
- Buffer: 20% (reason: unknowns)
- Total: 10h

### Confidence
- [ ] Low
- [x] Med
- [ ] High

### Schedule
- Start: 2025-01-15
- Target finish: 2025-01-20
- Milestones:
  - Design — 2025-01-16

### Post-estimate notes
**What could make this smaller?**
- Reuse code

**What could make this bigger?**
- Scope creep

**What did I ignore / forget last time?**
- Testing time

## Notes

## Tags
]]

      local task = task_format.text_to_task(text, "Job")

      -- Job details
      assert.are.equal("table", type(task.details))
      assert.are.equal("The context", task.details.context_why)
      assert.is_false(task.details.completed)
      assert.are.equal("- Done when X", task.details.outcome_dod)

      -- Estimation
      assert.is_not_nil(task.estimation)
      assert.are.equal("new_work", task.estimation.work_type)
      assert.are.equal("- Assumption 1", task.estimation.assumptions)
      assert.are.equal("three_point", task.estimation.effort.method)
      assert.are.equal(8, task.estimation.effort.base_hours)
      assert.are.equal(20, task.estimation.effort.buffer_percent)
      assert.are.equal("unknowns", task.estimation.effort.buffer_reason)
      assert.are.equal(10, task.estimation.effort.total_hours)
      assert.are.equal("med", task.estimation.confidence)
      assert.are.equal("2025-01-15", task.estimation.schedule.start_date)
      assert.are.equal("2025-01-20", task.estimation.schedule.target_finish)
    end)

    it("should parse completed Job checkbox", function()
      local text = [[
# Task: 1 - Job

## Details

### Context / Why
Context

- [x] Completed

## Notes

## Tags
]]

      local task = task_format.text_to_task(text, "Job")

      assert.is_true(task.details.completed)
    end)

    it("should parse GFM checkbox work types", function()
      local text = [[
# Task: 1 - Job

## Details

## Estimation

### Type
- [ ] New work
- [ ] Change
- [x] Bugfix
- [ ] Research/Spike

## Notes

## Tags
]]

      local task = task_format.text_to_task(text, "Job")

      assert.are.equal("bugfix", task.estimation.work_type)
    end)

    it("should parse GFM checkbox confidence levels", function()
      local text = [[
# Task: 1 - Job

## Details

## Estimation

### Confidence
- [x] Low
- [ ] Med
- [ ] High

## Notes

## Tags
]]

      local task = task_format.text_to_task(text, "Job")

      assert.are.equal("low", task.estimation.confidence)
    end)
  end)

  describe("Round-trip conversion", function()
    it("should round-trip Area task without data loss", function()
      local area_details = models.AreaDetails.new({
        vision_purpose = "Our vision for the future",
        goals_objectives = "- Goal 1\n- Goal 2\n- Goal 3",
        scope_boundaries = "- In scope item",
        key_components = "- Component A\n- Component B",
        success_metrics = "- Metric 1",
        stakeholders = "- Team Lead\n- Product Owner",
        dependencies_constraints = "- External API",
        strategic_context = "Part of Q1 initiative",
      })
      local original = models.Task.new("1", "Test Area", area_details, nil, {"area", "q1"}, "Important notes here")

      local text = task_format.task_to_text(original, "Area")
      local parsed = task_format.text_to_task(text, "Area")

      assert.are.equal(original.id, parsed.id)
      assert.are.equal(original.name, parsed.name)
      assert.are.equal(original.notes, parsed.notes)
      assert.are.same(original.tags, parsed.tags)

      assert.are.equal(original.details.vision_purpose, parsed.details.vision_purpose)
      assert.are.equal(original.details.goals_objectives, parsed.details.goals_objectives)
      assert.are.equal(original.details.scope_boundaries, parsed.details.scope_boundaries)
      assert.are.equal(original.details.key_components, parsed.details.key_components)
      assert.are.equal(original.details.success_metrics, parsed.details.success_metrics)
      assert.are.equal(original.details.stakeholders, parsed.details.stakeholders)
      assert.are.equal(original.details.dependencies_constraints, parsed.details.dependencies_constraints)
      assert.are.equal(original.details.strategic_context, parsed.details.strategic_context)
    end)

    it("should round-trip Component task without data loss", function()
      local component_details = models.ComponentDetails.new({
        purpose = "Handle user authentication",
        capabilities = "- Login\n- Logout\n- Password reset",
        acceptance_criteria = "- Users can log in\n- Sessions persist",
        architecture_design = "- JWT-based\n- Stateless",
        interfaces_integration = "- REST API\n- OAuth providers",
        quality_attributes = "- Response < 200ms",
        related_components = "- User Service\n- Session Store",
        other = "See RFC-123",
      })
      local original = models.Task.new("1.1", "Auth Component", component_details, nil, {"auth"}, "Check security docs")

      local text = task_format.task_to_text(original, "Component")
      local parsed = task_format.text_to_task(text, "Component")

      assert.are.equal(original.id, parsed.id)
      assert.are.equal(original.name, parsed.name)
      assert.are.equal(original.notes, parsed.notes)
      assert.are.same(original.tags, parsed.tags)

      assert.are.equal(original.details.purpose, parsed.details.purpose)
      assert.are.equal(original.details.capabilities, parsed.details.capabilities)
      assert.are.equal(original.details.acceptance_criteria, parsed.details.acceptance_criteria)
      assert.are.equal(original.details.architecture_design, parsed.details.architecture_design)
      assert.are.equal(original.details.interfaces_integration, parsed.details.interfaces_integration)
      assert.are.equal(original.details.quality_attributes, parsed.details.quality_attributes)
      assert.are.equal(original.details.related_components, parsed.details.related_components)
      assert.are.equal(original.details.other, parsed.details.other)
    end)

    it("should round-trip Job task with estimation without data loss", function()
      local job_details = models.JobDetails.new({
        context_why = "Users need this feature",
        outcome_dod = "- Feature works\n- Tests pass",
        scope_in = "- Core functionality",
        scope_out = "- Edge cases",
        requirements_constraints = "- Must use existing API",
        dependencies = "- Auth service ready",
        approach = "- Design\n- Implement\n- Test",
        risks = "- API might change",
        validation_test_plan = "- Unit tests\n- Integration tests",
        completed = false,
      })
      local estimation = models.Estimation.new({
        work_type = "new_work",
        assumptions = "- API stable\n- No blockers",
        effort = {
          method = "three_point",
          base_hours = 16,
          buffer_percent = 25,
          buffer_reason = "new technology",
          total_hours = 20,
        },
        confidence = "med",
        schedule = {
          start_date = "2025-02-01",
          target_finish = "2025-02-05",
          milestones = {{ name = "Design done", date = "2025-02-02" }},
        },
        post_estimate_notes = {
          could_be_smaller = "- Simpler scope",
          could_be_bigger = "- Requirements change",
          ignored_last_time = "- Code review time",
        },
      })
      local original = models.Task.new("1.1.1", "Implement Feature", job_details, estimation, {"feature", "sprint-1"}, "Priority: High")

      local text = task_format.task_to_text(original, "Job")
      local parsed = task_format.text_to_task(text, "Job")

      assert.are.equal(original.id, parsed.id)
      assert.are.equal(original.name, parsed.name)
      assert.are.equal(original.notes, parsed.notes)
      assert.are.same(original.tags, parsed.tags)

      -- Job details
      assert.are.equal(original.details.context_why, parsed.details.context_why)
      assert.are.equal(original.details.outcome_dod, parsed.details.outcome_dod)
      assert.are.equal(original.details.completed, parsed.details.completed)

      -- Estimation
      assert.are.equal(original.estimation.work_type, parsed.estimation.work_type)
      assert.are.equal(original.estimation.confidence, parsed.estimation.confidence)
      assert.are.equal(original.estimation.effort.method, parsed.estimation.effort.method)
      assert.are.equal(original.estimation.effort.base_hours, parsed.estimation.effort.base_hours)
      assert.are.equal(original.estimation.effort.buffer_percent, parsed.estimation.effort.buffer_percent)
      assert.are.equal(original.estimation.schedule.start_date, parsed.estimation.schedule.start_date)
      assert.are.equal(original.estimation.schedule.target_finish, parsed.estimation.schedule.target_finish)
    end)

    it("should round-trip completed Job", function()
      local job_details = models.JobDetails.new({
        context_why = "Completed task",
        completed = true,
      })
      local original = models.Task.new("1", "Done Job", job_details, nil, {}, "")

      local text = task_format.task_to_text(original, "Job")
      local parsed = task_format.text_to_task(text, "Job")

      assert.is_true(parsed.details.completed)
    end)
  end)

  describe("Markdown content preservation", function()
    it("should preserve markdown formatting in freeform fields", function()
      local component_details = models.ComponentDetails.new({
        purpose = "**Bold** and *italic* text",
        interfaces_integration = "### API\n```json\n{\"key\": \"value\"}\n```",
      })
      local original = models.Task.new("1", "Test", component_details, nil, {}, "")

      local text = task_format.task_to_text(original, "Component")
      local parsed = task_format.text_to_task(text, "Component")

      assert.are.equal("**Bold** and *italic* text", parsed.details.purpose)
      assert.is_true(parsed.details.interfaces_integration:find("```json") ~= nil,
        "Should preserve code blocks")
    end)

    it("should preserve code blocks in notes", function()
      local task = models.Task.new("1", "Test", "", nil, {}, "```lua\nlocal x = 1\n```")

      local text = task_format.task_to_text(task, "Area")
      local parsed = task_format.text_to_task(text, "Area")

      assert.is_true(parsed.notes:find("```lua") ~= nil)
      assert.is_true(parsed.notes:find("local x = 1") ~= nil)
    end)

    it("should preserve blank lines within content", function()
      local area_details = models.AreaDetails.new({
        vision_purpose = "First paragraph\n\nSecond paragraph\n\nThird paragraph",
      })
      local original = models.Task.new("1", "Test", area_details, nil, {}, "")

      local text = task_format.task_to_text(original, "Area")
      local parsed = task_format.text_to_task(text, "Area")

      assert.is_true(parsed.details.vision_purpose:find("First paragraph\n\nSecond") ~= nil,
        "Should preserve blank lines between paragraphs")
    end)
  end)

  describe("Edge cases", function()
    it("should handle empty task", function()
      local task = models.Task.new("1", "", nil, nil, {}, "")

      local text = task_format.task_to_text(task, "Area")
      local parsed = task_format.text_to_task(text, "Area")

      assert.are.equal("1", parsed.id)
      assert.are.equal("", parsed.name)
    end)

    it("should handle task ID with special characters", function()
      local task = models.Task.new("1.2.3", "Task with dots", nil, nil, {}, "")

      local text = task_format.task_to_text(task, "Area")
      local parsed = task_format.text_to_task(text, "Area")

      assert.are.equal("1.2.3", parsed.id)
    end)

    it("should handle task name with hyphen", function()
      local task = models.Task.new("1", "Task - with - hyphens", nil, nil, {}, "")

      local text = task_format.task_to_text(task, "Area")
      local parsed = task_format.text_to_task(text, "Area")

      assert.are.equal("Task - with - hyphens", parsed.name)
    end)

    it("should handle multiple tags with spaces", function()
      local task = models.Task.new("1", "Task", nil, nil, {"tag one", "tag two", "tag-three"}, "")

      local text = task_format.task_to_text(task, "Area")
      local parsed = task_format.text_to_task(text, "Area")

      assert.are.same({"tag one", "tag two", "tag-three"}, parsed.tags)
    end)
  end)
end)
