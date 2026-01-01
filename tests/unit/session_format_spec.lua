-- Unit tests for session text format conversion
-- Run with: luajit tests/unit/session_format_spec.lua

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

describe("Session Format", function()
  describe("session_to_text", function()
    it("should convert a basic session", function()
      local session = models.TimeLog.new(
        "2025-01-01T10:00:00Z",
        "2025-01-01T11:30:00Z",
        "Made good progress",
        "Phone call",
        10,
        {"1.1", "1.2"}
      )

      local text = session_format.session_to_text(session)

      assert.is_true(text:find("── Session") ~= nil)
      assert.is_true(text:find("Start: 2025%-01%-01 10:00") ~= nil)
      assert.is_true(text:find("End:%s+2025%-01%-01 11:30") ~= nil)
      assert.is_true(text:find("── Notes") ~= nil)
      assert.is_true(text:find("Made good progress") ~= nil)
      assert.is_true(text:find("── Interruptions") ~= nil)
      assert.is_true(text:find("Phone call") ~= nil)
      assert.is_true(text:find("── Tasks") ~= nil)
      assert.is_true(text:find("- 1%.1") ~= nil)
      assert.is_true(text:find("- 1%.2") ~= nil)
    end)

    it("should include new PSP and productivity fields", function()
      local session = models.TimeLog.new(
        "2025-01-01T10:00:00Z",
        "2025-01-01T11:30:00Z",
        "Made good progress",
        "",
        0,
        {"1.1"},
        "coding",
        90,
        4,
        { start = 5, ["end"] = 3 },
        2,
        { found = {"Bug in parser"}, fixed = {"Fixed parser bug"} },
        {"Session tracking feature", "Updated tests"},
        {"Unclear requirements"},
        {
          what_went_well = {"Good test coverage"},
          what_needs_improvement = {"Need better planning"},
          lessons_learned = {"Always read requirements twice"}
        }
      )

      local text = session_format.session_to_text(session)

      -- Check session header fields
      assert.is_true(text:find("Type:%s+coding") ~= nil)
      assert.is_true(text:find("Planned Duration %(min%):%s+90") ~= nil)

      -- Check productivity metrics
      assert.is_true(text:find("── Productivity Metrics") ~= nil)
      assert.is_true(text:find("Focus Rating %(1%-5%):%s+4") ~= nil)
      assert.is_true(text:find("Energy Level Start %(1%-5%):%s+5") ~= nil)
      assert.is_true(text:find("Energy Level End %(1%-5%):%s+3") ~= nil)
      assert.is_true(text:find("Context Switches:%s+2") ~= nil)

      -- Check deliverables
      assert.is_true(text:find("── Deliverables") ~= nil)
      assert.is_true(text:find("- Session tracking feature") ~= nil)
      assert.is_true(text:find("- Updated tests") ~= nil)

      -- Check defects
      assert.is_true(text:find("── Defects") ~= nil)
      assert.is_true(text:find("Found:") ~= nil)
      assert.is_true(text:find("- Bug in parser") ~= nil)
      assert.is_true(text:find("Fixed:") ~= nil)
      assert.is_true(text:find("- Fixed parser bug") ~= nil)

      -- Check blockers
      assert.is_true(text:find("── Blockers") ~= nil)
      assert.is_true(text:find("- Unclear requirements") ~= nil)

      -- Check retrospective
      assert.is_true(text:find("── Retrospective") ~= nil)
      assert.is_true(text:find("What Went Well:") ~= nil)
      assert.is_true(text:find("- Good test coverage") ~= nil)
      assert.is_true(text:find("What Needs Improvement:") ~= nil)
      assert.is_true(text:find("- Need better planning") ~= nil)
      assert.is_true(text:find("Lessons Learned:") ~= nil)
      assert.is_true(text:find("- Always read requirements twice") ~= nil)
    end)

    it("should handle empty optional fields gracefully", function()
      local session = models.TimeLog.new(
        "2025-01-01T10:00:00Z",
        "2025-01-01T11:30:00Z",
        "",
        "",
        0,
        {}
      )

      local text = session_format.session_to_text(session)

      -- Should still have all section headers
      assert.is_true(text:find("── Session") ~= nil)
      assert.is_true(text:find("── Productivity Metrics") ~= nil)
      assert.is_true(text:find("── Notes") ~= nil)
      assert.is_true(text:find("── Deliverables") ~= nil)
      assert.is_true(text:find("── Defects") ~= nil)
      assert.is_true(text:find("── Blockers") ~= nil)
      assert.is_true(text:find("── Retrospective") ~= nil)
      assert.is_true(text:find("── Tasks") ~= nil)
    end)
  end)

  describe("text_to_session", function()
    it("should parse a basic session", function()
      local text = [[
── Session ──────────────────────────
Start: 2025-01-01 10:00
End:   2025-01-01 11:30
Type:
Planned Duration (min): 0

── Productivity Metrics ─────────────
Focus Rating (1-5): 0
Energy Level Start (1-5): 0
Energy Level End (1-5): 0
Context Switches: 0

── Notes ────────────────────────────
Made good progress

── Interruptions (minutes: 10) ──────
Phone call

── Deliverables ─────────────────────

── Defects ──────────────────────────
Found:
Fixed:

── Blockers ─────────────────────────

── Retrospective ────────────────────
What Went Well:
What Needs Improvement:
Lessons Learned:

── Tasks ────────────────────────────
- 1.1
- 1.2
]]

      local session = session_format.text_to_session(text)

      assert.are.equal("2025-01-01T10:00:00Z", session.start_timestamp)
      assert.are.equal("2025-01-01T11:30:00Z", session.end_timestamp)
      assert.are.equal("Made good progress", session.notes)
      assert.are.equal("Phone call", session.interruptions)
      assert.are.equal(10, session.interruption_minutes)
      assert.are.equal(2, #session.tasks)
      assert.are.equal("1.1", session.tasks[1])
      assert.are.equal("1.2", session.tasks[2])
    end)

    it("should parse new PSP and productivity fields", function()
      local text = [[
── Session ──────────────────────────
Start: 2025-01-01 10:00
End:   2025-01-01 11:30
Type:  coding
Planned Duration (min): 90

── Productivity Metrics ─────────────
Focus Rating (1-5): 4
Energy Level Start (1-5): 5
Energy Level End (1-5): 3
Context Switches: 2

── Notes ────────────────────────────
Made good progress

── Interruptions (minutes: 0) ──────

── Deliverables ─────────────────────
- Session tracking feature
- Updated tests

── Defects ──────────────────────────
Found:
  - Bug in parser
Fixed:
  - Fixed parser bug

── Blockers ─────────────────────────
- Unclear requirements

── Retrospective ────────────────────
What Went Well:
  - Good test coverage
What Needs Improvement:
  - Need better planning
Lessons Learned:
  - Always read requirements twice

── Tasks ────────────────────────────
- 1.1
]]

      local session = session_format.text_to_session(text)

      assert.are.equal("coding", session.session_type)
      assert.are.equal(90, session.planned_duration_minutes)
      assert.are.equal(4, session.focus_rating)
      assert.are.equal(5, session.energy_level.start)
      assert.are.equal(3, session.energy_level["end"])
      assert.are.equal(2, session.context_switches)

      assert.are.equal(1, #session.defects.found)
      assert.are.equal("Bug in parser", session.defects.found[1])
      assert.are.equal(1, #session.defects.fixed)
      assert.are.equal("Fixed parser bug", session.defects.fixed[1])

      assert.are.equal(2, #session.deliverables)
      assert.are.equal("Session tracking feature", session.deliverables[1])
      assert.are.equal("Updated tests", session.deliverables[2])

      assert.are.equal(1, #session.blockers)
      assert.are.equal("Unclear requirements", session.blockers[1])

      assert.are.equal(1, #session.retrospective.what_went_well)
      assert.are.equal("Good test coverage", session.retrospective.what_went_well[1])
      assert.are.equal(1, #session.retrospective.what_needs_improvement)
      assert.are.equal("Need better planning", session.retrospective.what_needs_improvement[1])
      assert.are.equal(1, #session.retrospective.lessons_learned)
      assert.are.equal("Always read requirements twice", session.retrospective.lessons_learned[1])
    end)

    it("should round-trip session with all fields", function()
      local original = models.TimeLog.new(
        "2025-01-01T10:00:00Z",
        "2025-01-01T11:30:00Z",
        "Work notes",
        "Phone interruption",
        15,
        {"1.1", "2.1"},
        "testing",
        120,
        5,
        { start = 4, ["end"] = 4 },
        1,
        { found = {"Bug A", "Bug B"}, fixed = {"Bug C"} },
        {"Feature X", "Feature Y", "Feature Z"},
        {"Blocker 1", "Blocker 2"},
        {
          what_went_well = {"Fast progress", "Good tests"},
          what_needs_improvement = {"Documentation"},
          lessons_learned = {"Test first", "Review early"}
        }
      )

      local text = session_format.session_to_text(original)
      local parsed = session_format.text_to_session(text)

      -- Verify all fields match
      assert.are.equal(original.start_timestamp, parsed.start_timestamp)
      assert.are.equal(original.end_timestamp, parsed.end_timestamp)
      assert.are.equal(original.notes, parsed.notes)
      assert.are.equal(original.interruptions, parsed.interruptions)
      assert.are.equal(original.interruption_minutes, parsed.interruption_minutes)
      assert.are.equal(original.session_type, parsed.session_type)
      assert.are.equal(original.planned_duration_minutes, parsed.planned_duration_minutes)
      assert.are.equal(original.focus_rating, parsed.focus_rating)
      assert.are.equal(original.energy_level.start, parsed.energy_level.start)
      assert.are.equal(original.energy_level["end"], parsed.energy_level["end"])
      assert.are.equal(original.context_switches, parsed.context_switches)

      assert.are.same(original.tasks, parsed.tasks)
      assert.are.same(original.deliverables, parsed.deliverables)
      assert.are.same(original.blockers, parsed.blockers)
      assert.are.same(original.defects.found, parsed.defects.found)
      assert.are.same(original.defects.fixed, parsed.defects.fixed)
      assert.are.same(original.retrospective.what_went_well, parsed.retrospective.what_went_well)
      assert.are.same(original.retrospective.what_needs_improvement, parsed.retrospective.what_needs_improvement)
      assert.are.same(original.retrospective.lessons_learned, parsed.retrospective.lessons_learned)
    end)
  end)
end)
