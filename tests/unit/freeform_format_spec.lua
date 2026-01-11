-- Unit tests for Freeform component type
-- Run with: luajit tests/unit/freeform_format_spec.lua
--
-- Tests for the Freeform node type which has no predefined structure.
-- Content before any H3 headers goes to the 'content' field.
-- Any H3 headers are captured as custom sections.

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

describe("Freeform Format", function()
  describe("task_to_text for Freeform", function()
    it("should output empty Details section for empty FreeformDetails", function()
      local fd = models.FreeformDetails.new()
      local task = models.Task.new("1", "Freeform Task", fd, nil, {}, "")

      local text = task_format.task_to_text(task, "Freeform")

      assert.is_true(text:find("## Details\n") ~= nil,
        "Expected '## Details' section header")
      -- Should not have any H3 sections
      assert.is_true(text:find("### ") == nil,
        "Expected no H3 sections in empty freeform")
    end)

    it("should output content directly without H3 headers", function()
      local fd = models.FreeformDetails.new({
        content = "This is my freeform content.\nIt can have multiple lines."
      })
      local task = models.Task.new("1", "Freeform Task", fd, nil, {}, "")

      local text = task_format.task_to_text(task, "Freeform")

      assert.is_true(text:find("This is my freeform content%.") ~= nil,
        "Expected content to be in output")
      assert.is_true(text:find("It can have multiple lines%.") ~= nil,
        "Expected multiline content to be preserved")
    end)

    it("should output custom H3 sections", function()
      local fd = models.FreeformDetails.new({
        content = "Main content here",
        custom = { my_section = "Custom section content" }
      })
      local task = models.Task.new("1", "Freeform Task", fd, nil, {}, "")

      local text = task_format.task_to_text(task, "Freeform")

      assert.is_true(text:find("### My Section\n") ~= nil,
        "Expected custom H3 section header")
      assert.is_true(text:find("Custom section content") ~= nil,
        "Expected custom section content")
    end)

    it("should NOT include Estimation section", function()
      local fd = models.FreeformDetails.new({ content = "Some content" })
      local task = models.Task.new("1", "Freeform Task", fd, nil, {}, "")

      local text = task_format.task_to_text(task, "Freeform")

      assert.is_true(text:find("## Estimation") == nil,
        "Freeform should not have Estimation section")
    end)

    it("should include Notes and Tags sections", function()
      local fd = models.FreeformDetails.new({ content = "Content" })
      local task = models.Task.new("1", "Freeform Task", fd, nil, {"tag1"}, "My notes")

      local text = task_format.task_to_text(task, "Freeform")

      assert.is_true(text:find("## Notes\n") ~= nil,
        "Expected Notes section")
      assert.is_true(text:find("My notes") ~= nil,
        "Expected notes content")
      assert.is_true(text:find("## Tags\n") ~= nil,
        "Expected Tags section")
      assert.is_true(text:find("tag1") ~= nil,
        "Expected tag content")
    end)
  end)

  describe("text_to_task for Freeform", function()
    it("should parse content before any H3", function()
      local text = [[
# Task: 1 - My Freeform

## Details

This is freeform content.
It has multiple lines.

## Notes

## Tags
]]

      local task = task_format.text_to_task(text, "Freeform")

      assert.are.equal("1", task.id)
      assert.are.equal("My Freeform", task.name)
      assert.is_true(type(task.details) == "table",
        "Expected details to be FreeformDetails table")
      assert.is_true(task.details.content:find("This is freeform content") ~= nil,
        "Expected content to contain freeform text")
    end)

    it("should parse H3 sections as custom fields", function()
      local text = [[
# Task: 1 - My Freeform

## Details

Some intro content.

### My Custom Section

Custom content here.

### Another Section

More custom content.

## Notes

## Tags
]]

      local task = task_format.text_to_task(text, "Freeform")

      assert.is_true(task.details.content:find("Some intro content") ~= nil,
        "Expected intro content before H3")
      assert.is_true(task.details.custom.my_custom_section ~= nil,
        "Expected my_custom_section in custom")
      assert.is_true(task.details.custom.my_custom_section:find("Custom content here") ~= nil,
        "Expected custom section content")
      assert.is_true(task.details.custom.another_section ~= nil,
        "Expected another_section in custom")
    end)

    it("should handle empty Details section", function()
      local text = [[
# Task: 1 - Empty Freeform

## Details

## Notes

## Tags
]]

      local task = task_format.text_to_task(text, "Freeform")

      assert.are.equal("", task.details.content)
      assert.are.same({}, task.details.custom)
    end)
  end)

  describe("round-trip conversion", function()
    it("should round-trip freeform content", function()
      local fd = models.FreeformDetails.new({
        content = "My freeform content\nWith multiple lines"
      })
      local original = models.Task.new("1", "Freeform Task", fd, nil, {}, "")

      local text = task_format.task_to_text(original, "Freeform")
      local parsed = task_format.text_to_task(text, "Freeform")

      assert.are.equal(original.id, parsed.id)
      assert.are.equal(original.name, parsed.name)
      assert.is_true(parsed.details.content:find("My freeform content") ~= nil,
        "Expected content to be preserved")
    end)

    it("should round-trip freeform with custom H3 sections", function()
      local fd = models.FreeformDetails.new({
        content = "Main content",
        custom = {
          section_one = "First section",
          section_two = "Second section"
        }
      })
      local original = models.Task.new("1", "Freeform Task", fd, nil, {"tag1"}, "Notes here")

      local text = task_format.task_to_text(original, "Freeform")
      local parsed = task_format.text_to_task(text, "Freeform")

      assert.is_true(parsed.details.content:find("Main content") ~= nil,
        "Expected main content to be preserved")
      assert.is_true(parsed.details.custom.section_one ~= nil,
        "Expected section_one in custom")
      assert.is_true(parsed.details.custom.section_two ~= nil,
        "Expected section_two in custom")
      assert.are.equal("Notes here", parsed.notes)
      assert.are.same({"tag1"}, parsed.tags)
    end)

    it("should round-trip empty freeform", function()
      local fd = models.FreeformDetails.new()
      local original = models.Task.new("1", "Empty", fd, nil, {}, "")

      local text = task_format.task_to_text(original, "Freeform")
      local parsed = task_format.text_to_task(text, "Freeform")

      assert.are.equal("", parsed.details.content)
      assert.are.same({}, parsed.details.custom)
    end)
  end)

  describe("Task.new type detection", function()
    it("should detect FreeformDetails from content field", function()
      local task = models.Task.new("1", "Test", { content = "Some content" })
      -- After construction, details should be FreeformDetails
      assert.are.equal("Some content", task.details.content)
    end)

    it("should not confuse FreeformDetails with other types", function()
      -- JobDetails has context_why, outcome_dod, approach
      local job_data = { context_why = "Why", content = "Content" }
      local job_task = models.Task.new("1", "Test", job_data)
      -- Should be JobDetails (has job fields), not FreeformDetails
      assert.are.equal("Why", job_task.details.context_why)

      -- ComponentDetails has purpose, capabilities
      local comp_data = { purpose = "Purpose", content = "Content" }
      local comp_task = models.Task.new("1", "Test", comp_data)
      assert.are.equal("Purpose", comp_task.details.purpose)
    end)
  end)

  describe("edge cases", function()
    it("should handle content with markdown formatting", function()
      local fd = models.FreeformDetails.new({
        content = "# This is a header\n\n**Bold** and *italic*\n\n- List item 1\n- List item 2"
      })
      local task = models.Task.new("1", "Markdown Content", fd, nil, {}, "")

      local text = task_format.task_to_text(task, "Freeform")
      local parsed = task_format.text_to_task(text, "Freeform")

      assert.is_true(parsed.details.content:find("%*%*Bold%*%*") ~= nil,
        "Expected bold markdown to be preserved")
      assert.is_true(parsed.details.content:find("%- List item 1") ~= nil,
        "Expected list items to be preserved")
    end)

    it("should handle content with code blocks", function()
      local fd = models.FreeformDetails.new({
        content = "```lua\nlocal x = 1\n```"
      })
      local task = models.Task.new("1", "Code Block", fd, nil, {}, "")

      local text = task_format.task_to_text(task, "Freeform")
      local parsed = task_format.text_to_task(text, "Freeform")

      assert.is_true(parsed.details.content:find("```lua") ~= nil,
        "Expected code block to be preserved")
    end)

    it("should preserve blank lines in content", function()
      local fd = models.FreeformDetails.new({
        content = "Paragraph 1\n\nParagraph 2\n\nParagraph 3"
      })
      local task = models.Task.new("1", "Paragraphs", fd, nil, {}, "")

      local text = task_format.task_to_text(task, "Freeform")
      local parsed = task_format.text_to_task(text, "Freeform")

      assert.is_true(parsed.details.content:find("Paragraph 1") ~= nil)
      assert.is_true(parsed.details.content:find("Paragraph 2") ~= nil)
      assert.is_true(parsed.details.content:find("Paragraph 3") ~= nil)
    end)
  end)
end)

-- Print summary at end
print("Run this test with: lua tests/unit/freeform_format_spec.lua")
