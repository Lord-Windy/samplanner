-- Unit tests for Markdown session format conversion
-- Run with: luajit tests/unit/markdown_session_format_spec.lua
--
-- These tests define the expected behavior for the new Markdown session format.
-- The format uses:
-- - H2 (##) for major sections: ## Session, ## Productivity Metrics, etc.
-- - H3 (###) for sub-sections where needed
-- - GFM-style checkboxes and lists

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
local session_format = require('samplanner.formats.session')

describe("Markdown Session Format", function()
  describe("session_to_text output format", function()
    it("should output H2 for Session section", function()
      local session = models.TimeLog.new(
        "2025-01-01T10:00:00Z",
        "2025-01-01T11:30:00Z",
        "",
        "",
        0,
        {}
      )

      local text = session_format.session_to_text(session)

      assert.is_true(text:find("^## Session\n") ~= nil,
        "Expected '## Session' header at start")
    end)

    it("should output H2 for Productivity Metrics section", function()
      local session = models.TimeLog.new(
        "2025-01-01T10:00:00Z",
        "2025-01-01T11:30:00Z",
        "",
        "",
        0,
        {}
      )

      local text = session_format.session_to_text(session)

      assert.is_true(text:find("\n## Productivity Metrics\n") ~= nil,
        "Expected '## Productivity Metrics' section header")
    end)

    it("should output H2 for Notes section", function()
      local session = models.TimeLog.new(
        "2025-01-01T10:00:00Z",
        "2025-01-01T11:30:00Z",
        "Some notes",
        "",
        0,
        {}
      )

      local text = session_format.session_to_text(session)

      assert.is_true(text:find("\n## Notes\n") ~= nil,
        "Expected '## Notes' section header")
    end)

    it("should output H2 for Interruptions section", function()
      local session = models.TimeLog.new(
        "2025-01-01T10:00:00Z",
        "2025-01-01T11:30:00Z",
        "",
        "Phone call",
        15,
        {}
      )

      local text = session_format.session_to_text(session)

      assert.is_true(text:find("\n## Interruptions") ~= nil,
        "Expected '## Interruptions' section header")
    end)

    it("should output H2 for Deliverables section", function()
      local session = models.TimeLog.new(
        "2025-01-01T10:00:00Z",
        "2025-01-01T11:30:00Z",
        "",
        "",
        0,
        {},
        nil, nil, nil, nil, nil, nil,
        "- Feature X"
      )

      local text = session_format.session_to_text(session)

      assert.is_true(text:find("\n## Deliverables\n") ~= nil,
        "Expected '## Deliverables' section header")
    end)

    it("should output H2 for Defects section", function()
      local session = models.TimeLog.new(
        "2025-01-01T10:00:00Z",
        "2025-01-01T11:30:00Z",
        "",
        "",
        0,
        {},
        nil, nil, nil, nil, nil,
        { found = "- Bug 1", fixed = "- Fix 1" }
      )

      local text = session_format.session_to_text(session)

      assert.is_true(text:find("\n## Defects\n") ~= nil,
        "Expected '## Defects' section header")
    end)

    it("should output H2 for Blockers section", function()
      local session = models.TimeLog.new(
        "2025-01-01T10:00:00Z",
        "2025-01-01T11:30:00Z",
        "",
        "",
        0,
        {},
        nil, nil, nil, nil, nil, nil, nil,
        "- Blocker 1"
      )

      local text = session_format.session_to_text(session)

      assert.is_true(text:find("\n## Blockers\n") ~= nil,
        "Expected '## Blockers' section header")
    end)

    it("should output H2 for Retrospective section", function()
      local session = models.TimeLog.new(
        "2025-01-01T10:00:00Z",
        "2025-01-01T11:30:00Z",
        "",
        "",
        0,
        {}
      )

      local text = session_format.session_to_text(session)

      assert.is_true(text:find("\n## Retrospective\n") ~= nil,
        "Expected '## Retrospective' section header")
    end)

    it("should output H2 for Tasks section", function()
      local session = models.TimeLog.new(
        "2025-01-01T10:00:00Z",
        "2025-01-01T11:30:00Z",
        "",
        "",
        0,
        {"1.1", "1.2"}
      )

      local text = session_format.session_to_text(session)

      assert.is_true(text:find("\n## Tasks\n") ~= nil,
        "Expected '## Tasks' section header")
    end)
  end)

  describe("Session header fields formatting", function()
    it("should format timestamps correctly", function()
      local session = models.TimeLog.new(
        "2025-01-01T10:00:00Z",
        "2025-01-01T11:30:00Z",
        "",
        "",
        0,
        {}
      )

      local text = session_format.session_to_text(session)

      assert.is_true(text:find("Start: 2025%-01%-01 10:00") ~= nil,
        "Expected formatted start timestamp")
      assert.is_true(text:find("End:%s+2025%-01%-01 11:30") ~= nil,
        "Expected formatted end timestamp")
    end)

    it("should format session type", function()
      local session = models.TimeLog.new(
        "2025-01-01T10:00:00Z",
        "2025-01-01T11:30:00Z",
        "",
        "",
        0,
        {},
        "coding"
      )

      local text = session_format.session_to_text(session)

      assert.is_true(text:find("Type:%s+coding") ~= nil,
        "Expected session type")
    end)

    it("should format planned duration", function()
      local session = models.TimeLog.new(
        "2025-01-01T10:00:00Z",
        "2025-01-01T11:30:00Z",
        "",
        "",
        0,
        {},
        nil,
        90
      )

      local text = session_format.session_to_text(session)

      assert.is_true(text:find("Planned Duration %(min%):%s+90") ~= nil,
        "Expected planned duration")
    end)
  end)

  describe("Productivity metrics formatting", function()
    it("should format all productivity metrics", function()
      local session = models.TimeLog.new(
        "2025-01-01T10:00:00Z",
        "2025-01-01T11:30:00Z",
        "",
        "",
        0,
        {},
        "coding",
        90,
        4,
        { start = 5, ["end"] = 3 },
        2
      )

      local text = session_format.session_to_text(session)

      assert.is_true(text:find("Focus Rating %(1%-5%):%s+4") ~= nil)
      assert.is_true(text:find("Energy Level Start %(1%-5%):%s+5") ~= nil)
      assert.is_true(text:find("Energy Level End %(1%-5%):%s+3") ~= nil)
      assert.is_true(text:find("Context Switches:%s+2") ~= nil)
    end)
  end)

  describe("Defects section formatting", function()
    it("should format defects with H3 sub-sections", function()
      local session = models.TimeLog.new(
        "2025-01-01T10:00:00Z",
        "2025-01-01T11:30:00Z",
        "",
        "",
        0,
        {},
        nil, nil, nil, nil, nil,
        { found = "- Bug in parser", fixed = "- Fixed parser" }
      )

      local text = session_format.session_to_text(session)

      assert.is_true(text:find("\n### Found\n") ~= nil,
        "Expected '### Found' sub-section")
      assert.is_true(text:find("\n### Fixed\n") ~= nil,
        "Expected '### Fixed' sub-section")
    end)
  end)

  describe("Retrospective section formatting", function()
    it("should format retrospective with H3 sub-sections", function()
      local session = models.TimeLog.new(
        "2025-01-01T10:00:00Z",
        "2025-01-01T11:30:00Z",
        "",
        "",
        0,
        {},
        nil, nil, nil, nil, nil, nil, nil, nil,
        {
          what_went_well = "- Good progress",
          what_needs_improvement = "- Better planning",
          lessons_learned = "- Test first"
        }
      )

      local text = session_format.session_to_text(session)

      assert.is_true(text:find("\n### What Went Well\n") ~= nil,
        "Expected '### What Went Well' sub-section")
      assert.is_true(text:find("\n### What Needs Improvement\n") ~= nil,
        "Expected '### What Needs Improvement' sub-section")
      assert.is_true(text:find("\n### Lessons Learned\n") ~= nil,
        "Expected '### Lessons Learned' sub-section")
    end)
  end)

  describe("text_to_session parsing", function()
    it("should parse H2 Session section", function()
      local text = [[
## Session
Start: 2025-01-01 10:00
End:   2025-01-01 11:30
Type:  coding
Planned Duration (min): 90

## Productivity Metrics
Focus Rating (1-5): 0
Energy Level Start (1-5): 0
Energy Level End (1-5): 0
Context Switches: 0

## Notes

## Interruptions (minutes: 0)

## Deliverables

## Defects
### Found
### Fixed

## Blockers

## Retrospective
### What Went Well
### What Needs Improvement
### Lessons Learned

## Tasks
]]

      local session = session_format.text_to_session(text)

      assert.are.equal("2025-01-01T10:00:00Z", session.start_timestamp)
      assert.are.equal("2025-01-01T11:30:00Z", session.end_timestamp)
      assert.are.equal("coding", session.session_type)
      assert.are.equal(90, session.planned_duration_minutes)
    end)

    it("should parse H2 Productivity Metrics section", function()
      local text = [[
## Session
Start: 2025-01-01 10:00
End:   2025-01-01 11:30

## Productivity Metrics
Focus Rating (1-5): 4
Energy Level Start (1-5): 5
Energy Level End (1-5): 3
Context Switches: 2

## Notes

## Tasks
]]

      local session = session_format.text_to_session(text)

      assert.are.equal(4, session.focus_rating)
      assert.are.equal(5, session.energy_level.start)
      assert.are.equal(3, session.energy_level["end"])
      assert.are.equal(2, session.context_switches)
    end)

    it("should parse H2 Notes section", function()
      local text = [[
## Session
Start: 2025-01-01 10:00
End:   2025-01-01 11:30

## Notes
Made good progress on the feature
Multiple lines of notes

## Tasks
]]

      local session = session_format.text_to_session(text)

      assert.is_true(session.notes:find("Made good progress") ~= nil)
    end)

    it("should parse H2 Interruptions section", function()
      local text = [[
## Session
Start: 2025-01-01 10:00
End:   2025-01-01 11:30

## Interruptions (minutes: 15)
Phone call
Meeting

## Tasks
]]

      local session = session_format.text_to_session(text)

      assert.are.equal(15, session.interruption_minutes)
      assert.is_true(session.interruptions:find("Phone call") ~= nil)
    end)

    it("should parse H2 Deliverables section", function()
      local text = [[
## Session
Start: 2025-01-01 10:00
End:   2025-01-01 11:30

## Deliverables
- Feature X completed
- Tests added

## Tasks
]]

      local session = session_format.text_to_session(text)

      assert.is_true(session.deliverables:find("Feature X completed") ~= nil)
      assert.is_true(session.deliverables:find("Tests added") ~= nil)
    end)

    it("should parse H3 Defects sub-sections", function()
      local text = [[
## Session
Start: 2025-01-01 10:00
End:   2025-01-01 11:30

## Defects
### Found
- Bug in parser
- Memory leak
### Fixed
- Fixed parser bug

## Tasks
]]

      local session = session_format.text_to_session(text)

      assert.is_true(session.defects.found:find("Bug in parser") ~= nil)
      assert.is_true(session.defects.found:find("Memory leak") ~= nil)
      assert.is_true(session.defects.fixed:find("Fixed parser bug") ~= nil)
    end)

    it("should parse H2 Blockers section", function()
      local text = [[
## Session
Start: 2025-01-01 10:00
End:   2025-01-01 11:30

## Blockers
- Waiting for API access
- Unclear requirements

## Tasks
]]

      local session = session_format.text_to_session(text)

      assert.is_true(session.blockers:find("Waiting for API access") ~= nil)
      assert.is_true(session.blockers:find("Unclear requirements") ~= nil)
    end)

    it("should parse H3 Retrospective sub-sections", function()
      local text = [[
## Session
Start: 2025-01-01 10:00
End:   2025-01-01 11:30

## Retrospective
### What Went Well
- Good test coverage
- Fast progress
### What Needs Improvement
- Need better planning
### Lessons Learned
- Always read requirements twice

## Tasks
]]

      local session = session_format.text_to_session(text)

      assert.is_true(session.retrospective.what_went_well:find("Good test coverage") ~= nil)
      assert.is_true(session.retrospective.what_went_well:find("Fast progress") ~= nil)
      assert.is_true(session.retrospective.what_needs_improvement:find("Need better planning") ~= nil)
      assert.is_true(session.retrospective.lessons_learned:find("Always read requirements twice") ~= nil)
    end)

    it("should parse H2 Tasks section", function()
      local text = [[
## Session
Start: 2025-01-01 10:00
End:   2025-01-01 11:30

## Tasks
- 1.1
- 1.2.3
- 2.1
]]

      local session = session_format.text_to_session(text)

      assert.are.equal(3, #session.tasks)
      assert.are.equal("1.1", session.tasks[1])
      assert.are.equal("1.2.3", session.tasks[2])
      assert.are.equal("2.1", session.tasks[3])
    end)
  end)

  describe("Round-trip conversion", function()
    it("should round-trip session with all fields", function()
      local original = models.TimeLog.new(
        "2025-01-01T10:00:00Z",
        "2025-01-01T11:30:00Z",
        "Work notes here",
        "Phone interruption",
        15,
        {"1.1", "2.1"},
        "testing",
        120,
        5,
        { start = 4, ["end"] = 4 },
        1,
        { found = "- Bug A\n- Bug B", fixed = "- Bug C" },
        "- Feature X\n- Feature Y\n- Feature Z",
        "- Blocker 1\n- Blocker 2",
        {
          what_went_well = "- Fast progress\n- Good tests",
          what_needs_improvement = "- Documentation",
          lessons_learned = "- Test first\n- Review early"
        }
      )

      local text = session_format.session_to_text(original)
      local parsed = session_format.text_to_session(text)

      -- Basic fields
      assert.are.equal(original.start_timestamp, parsed.start_timestamp)
      assert.are.equal(original.end_timestamp, parsed.end_timestamp)
      assert.are.equal(original.session_type, parsed.session_type)
      assert.are.equal(original.planned_duration_minutes, parsed.planned_duration_minutes)

      -- Productivity metrics
      assert.are.equal(original.focus_rating, parsed.focus_rating)
      assert.are.equal(original.energy_level.start, parsed.energy_level.start)
      assert.are.equal(original.energy_level["end"], parsed.energy_level["end"])
      assert.are.equal(original.context_switches, parsed.context_switches)

      -- Content fields
      assert.are.equal(original.notes, parsed.notes)
      assert.are.equal(original.interruptions, parsed.interruptions)
      assert.are.equal(original.interruption_minutes, parsed.interruption_minutes)

      -- Lists
      assert.are.same(original.tasks, parsed.tasks)
      assert.are.equal(original.deliverables, parsed.deliverables)
      assert.are.equal(original.blockers, parsed.blockers)

      -- Defects
      assert.are.equal(original.defects.found, parsed.defects.found)
      assert.are.equal(original.defects.fixed, parsed.defects.fixed)

      -- Retrospective
      assert.are.equal(original.retrospective.what_went_well, parsed.retrospective.what_went_well)
      assert.are.equal(original.retrospective.what_needs_improvement, parsed.retrospective.what_needs_improvement)
      assert.are.equal(original.retrospective.lessons_learned, parsed.retrospective.lessons_learned)
    end)

    it("should round-trip minimal session", function()
      local original = models.TimeLog.new(
        "2025-01-01T10:00:00Z",
        "2025-01-01T11:30:00Z",
        "",
        "",
        0,
        {}
      )

      local text = session_format.session_to_text(original)
      local parsed = session_format.text_to_session(text)

      assert.are.equal(original.start_timestamp, parsed.start_timestamp)
      assert.are.equal(original.end_timestamp, parsed.end_timestamp)
      assert.are.equal(0, #parsed.tasks)
    end)
  end)

  describe("Markdown content preservation", function()
    it("should preserve markdown in notes", function()
      local original = models.TimeLog.new(
        "2025-01-01T10:00:00Z",
        "2025-01-01T11:30:00Z",
        "**Bold** note with `code`",
        "",
        0,
        {}
      )

      local text = session_format.session_to_text(original)
      local parsed = session_format.text_to_session(text)

      assert.are.equal("**Bold** note with `code`", parsed.notes)
    end)

    it("should preserve code blocks in deliverables", function()
      local original = models.TimeLog.new(
        "2025-01-01T10:00:00Z",
        "2025-01-01T11:30:00Z",
        "",
        "",
        0,
        {},
        nil, nil, nil, nil, nil, nil,
        "```lua\nlocal x = 1\n```"
      )

      local text = session_format.session_to_text(original)
      local parsed = session_format.text_to_session(text)

      assert.is_true(parsed.deliverables:find("```lua") ~= nil)
    end)
  end)

  describe("Edge cases", function()
    it("should handle empty end timestamp (active session)", function()
      local session = models.TimeLog.new(
        "2025-01-01T10:00:00Z",
        "",
        "",
        "",
        0,
        {}
      )

      local text = session_format.session_to_text(session)
      local parsed = session_format.text_to_session(text)

      assert.are.equal("2025-01-01T10:00:00Z", parsed.start_timestamp)
      assert.are.equal("", parsed.end_timestamp)
    end)

    it("should handle zero values for metrics", function()
      local session = models.TimeLog.new(
        "2025-01-01T10:00:00Z",
        "2025-01-01T11:30:00Z",
        "",
        "",
        0,
        {},
        nil,
        0,
        0,
        { start = 0, ["end"] = 0 },
        0
      )

      local text = session_format.session_to_text(session)
      local parsed = session_format.text_to_session(text)

      assert.are.equal(0, parsed.planned_duration_minutes)
      assert.are.equal(0, parsed.focus_rating)
      assert.are.equal(0, parsed.energy_level.start)
      assert.are.equal(0, parsed.context_switches)
    end)
  end)
end)
