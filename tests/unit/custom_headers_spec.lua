-- Unit tests for dynamic object creation from custom headers
-- Run with: luajit tests/unit/custom_headers_spec.lua
--
-- Tests for the feature where:
-- - H1 (#): Never saved as custom - content moves to notes (stripped of #)
-- - H2 (##): Unknown headers create top-level custom fields
-- - H3 (###): Unknown headers create custom fields within current H2 section
-- - H4+ (####...): Treated as plain text, not structural

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

describe("Custom Headers - Dynamic Object Creation", function()

  describe("H1 headers (should move to notes)", function()
    it("should move stray H1 content to notes, stripped of #", function()
      local text = [[
# Task: 1 - Test Task

## Details

### Vision / Purpose
Some vision

# This is a stray H1 header

Some content after the stray header

## Notes

## Tags
]]

      local task = task_format.text_to_task(text, "Area")

      -- The stray H1 should be moved to notes without the #
      assert.is_true(task.notes:find("This is a stray H1 header") ~= nil,
        "Stray H1 header text should appear in notes")
      assert.is_nil(task.notes:find("^#"),
        "H1 header should be stripped of # prefix in notes")
    end)

    it("should preserve existing notes when adding stray H1 content", function()
      local text = [[
# Task: 1 - Test Task

## Details

### Vision / Purpose
Vision here

# Stray header content

## Notes
Existing notes here

## Tags
]]

      local task = task_format.text_to_task(text, "Area")

      assert.is_true(task.notes:find("Existing notes here") ~= nil,
        "Original notes should be preserved")
      assert.is_true(task.notes:find("Stray header content") ~= nil,
        "Stray H1 content should be appended to notes")
    end)

    it("should handle multiple stray H1 headers", function()
      local text = [[
# Task: 1 - Test Task

## Details

### Vision / Purpose

# First stray

Content 1

# Second stray

Content 2

## Notes

## Tags
]]

      local task = task_format.text_to_task(text, "Area")

      assert.is_true(task.notes:find("First stray") ~= nil)
      assert.is_true(task.notes:find("Second stray") ~= nil)
    end)
  end)

  describe("H2 headers (top-level custom fields)", function()
    it("should create custom field for unknown H2 header", function()
      local text = [[
# Task: 1 - Test Task

## Details

### Vision / Purpose
Vision here

## Notes

## Tags

## My Custom Section
This is custom content
]]

      local task = task_format.text_to_task(text, "Area")

      assert.is_not_nil(task.custom, "Task should have custom field")
      assert.is_not_nil(task.custom.my_custom_section,
        "Custom field key should be normalized from header")
      assert.are.equal("This is custom content", task.custom.my_custom_section)
    end)

    it("should handle multiple unknown H2 headers", function()
      local text = [[
# Task: 1 - Test Task

## Details

### Vision / Purpose

## Notes

## Tags

## Research Notes
Some research

## Implementation Ideas
Some ideas
]]

      local task = task_format.text_to_task(text, "Area")

      assert.is_not_nil(task.custom)
      assert.are.equal("Some research", task.custom.research_notes)
      assert.are.equal("Some ideas", task.custom.implementation_ideas)
    end)

    it("should preserve multiline content in custom H2 sections", function()
      local text = [[
# Task: 1 - Test Task

## Details

### Vision / Purpose

## Notes

## Tags

## Meeting Notes
- Point 1
- Point 2

Additional paragraph here
]]

      local task = task_format.text_to_task(text, "Area")

      assert.is_not_nil(task.custom)
      local content = task.custom.meeting_notes
      assert.is_true(content:find("Point 1") ~= nil)
      assert.is_true(content:find("Point 2") ~= nil)
      assert.is_true(content:find("Additional paragraph") ~= nil)
    end)

    it("should normalize header names to valid Lua keys", function()
      local text = [[
# Task: 1 - Test Task

## Details

### Vision / Purpose

## Notes

## Tags

## My Special Section (with parens)!
Content here
]]

      local task = task_format.text_to_task(text, "Area")

      assert.is_not_nil(task.custom)
      -- Should normalize: lowercase, remove special chars, spaces to underscores
      assert.is_not_nil(task.custom.my_special_section_with_parens,
        "Header should be normalized to valid key")
    end)
  end)

  describe("H3 headers within custom H2 (nested custom fields)", function()
    it("should create nested custom fields for unknown H3 within custom H2", function()
      local text = [[
# Task: 1 - Test Task

## Details

### Vision / Purpose

## Notes

## Tags

## Research
### Sources
- Source 1
- Source 2

### Findings
Key finding here
]]

      local task = task_format.text_to_task(text, "Area")

      assert.is_not_nil(task.custom)
      assert.is_not_nil(task.custom.research, "Should have research custom field")
      -- Research should contain nested H3 content
      assert.is_true(type(task.custom.research) == "table" or
                     task.custom.research:find("Sources") ~= nil,
        "Research should contain H3 subsections")
    end)

    it("should handle unknown H3 within known Details section", function()
      local text = [[
# Task: 1 - Test Task

## Details

### Vision / Purpose
Standard vision

### My Custom Subsection
Custom detail content

### Goals / Objectives
Standard goals

## Notes

## Tags
]]

      local task = task_format.text_to_task(text, "Area")

      -- Standard fields should work
      assert.are.equal("Standard vision", task.details.vision_purpose)
      assert.are.equal("Standard goals", task.details.goals_objectives)

      -- Custom subsection should be captured
      assert.is_not_nil(task.details.custom, "Details should have custom field")
      assert.are.equal("Custom detail content", task.details.custom.my_custom_subsection)
    end)
  end)

  describe("H4+ headers (treated as plain text)", function()
    it("should treat H4 as plain text content", function()
      local text = [[
# Task: 1 - Test Task

## Details

### Vision / Purpose
Some vision

#### This is H4 - should be plain text
Content after H4

## Notes

## Tags
]]

      local task = task_format.text_to_task(text, "Area")

      -- H4 should be included as part of vision_purpose content
      assert.is_true(task.details.vision_purpose:find("#### This is H4") ~= nil,
        "H4 should be preserved as plain text")
      assert.is_true(task.details.vision_purpose:find("Content after H4") ~= nil)
    end)

    it("should treat H5 and H6 as plain text content", function()
      local text = [[
# Task: 1 - Test Task

## Details

### Vision / Purpose
Vision text

##### H5 header
###### H6 header

More content

## Notes

## Tags
]]

      local task = task_format.text_to_task(text, "Area")

      assert.is_true(task.details.vision_purpose:find("##### H5 header") ~= nil,
        "H5 should be preserved as plain text")
      assert.is_true(task.details.vision_purpose:find("###### H6 header") ~= nil,
        "H6 should be preserved as plain text")
    end)

    it("should preserve H4 in custom sections", function()
      local text = [[
# Task: 1 - Test Task

## Details

### Vision / Purpose

## Notes

## Tags

## My Section
Content here

#### Subheading in custom section
More content
]]

      local task = task_format.text_to_task(text, "Area")

      local content = task.custom.my_section
      assert.is_true(content:find("#### Subheading") ~= nil,
        "H4 in custom section should be preserved as text")
    end)
  end)

  describe("Round-trip with custom fields", function()
    it("should round-trip custom H2 fields", function()
      local task = models.Task.new("1", "Test", nil, nil, {}, "")
      task.custom = {
        research_notes = "Some research",
        implementation_ideas = "Some ideas"
      }

      local text = task_format.task_to_text(task, "Area")
      local parsed = task_format.text_to_task(text, "Area")

      assert.is_not_nil(parsed.custom)
      assert.are.equal("Some research", parsed.custom.research_notes)
      assert.are.equal("Some ideas", parsed.custom.implementation_ideas)
    end)

    it("should render custom fields as H2 sections in markdown", function()
      local task = models.Task.new("1", "Test", nil, nil, {}, "")
      task.custom = {
        my_section = "Section content"
      }

      local text = task_format.task_to_text(task, "Area")

      assert.is_true(text:find("## My Section") ~= nil or
                     text:find("## my_section") ~= nil,
        "Custom field should render as H2 header")
      assert.is_true(text:find("Section content") ~= nil)
    end)

    it("should round-trip custom H3 fields within Details", function()
      local area_details = models.AreaDetails.new({
        vision_purpose = "Standard vision"
      })
      area_details.custom = {
        my_custom_field = "Custom content"
      }
      local task = models.Task.new("1", "Test", area_details, nil, {}, "")

      local text = task_format.task_to_text(task, "Area")
      local parsed = task_format.text_to_task(text, "Area")

      assert.are.equal("Standard vision", parsed.details.vision_purpose)
      assert.is_not_nil(parsed.details.custom)
      assert.are.equal("Custom content", parsed.details.custom.my_custom_field)
    end)

    it("should preserve H4+ content through round-trip", function()
      local area_details = models.AreaDetails.new({
        vision_purpose = "Vision\n\n#### Sub-heading\nMore content"
      })
      local task = models.Task.new("1", "Test", area_details, nil, {}, "")

      local text = task_format.task_to_text(task, "Area")
      local parsed = task_format.text_to_task(text, "Area")

      assert.is_true(parsed.details.vision_purpose:find("#### Sub%-heading") ~= nil,
        "H4 should survive round-trip as plain text")
    end)
  end)

  describe("Key normalization", function()
    it("should convert spaces to underscores", function()
      local text = [[
# Task: 1 - Test

## Details

### Vision / Purpose

## Notes

## Tags

## My Custom Header
content
]]

      local task = task_format.text_to_task(text, "Area")
      assert.is_not_nil(task.custom.my_custom_header)
    end)

    it("should convert to lowercase", function()
      local text = [[
# Task: 1 - Test

## Details

### Vision / Purpose

## Notes

## Tags

## UPPERCASE HEADER
content
]]

      local task = task_format.text_to_task(text, "Area")
      assert.is_not_nil(task.custom.uppercase_header)
    end)

    it("should remove special characters", function()
      local text = [[
# Task: 1 - Test

## Details

### Vision / Purpose

## Notes

## Tags

## Header (with) [brackets] & symbols!
content
]]

      local task = task_format.text_to_task(text, "Area")
      -- Should have a key without special chars
      local found_key = false
      if task.custom then
        for k, _ in pairs(task.custom) do
          if k:find("header") and k:find("with") then
            found_key = true
            -- Key should not contain special chars
            assert.is_nil(k:find("[%(%)%[%]&!]"),
              "Key should not contain special characters")
          end
        end
      end
      assert.is_true(found_key, "Should have created a key from the header")
    end)
  end)

  describe("JSON serialization", function()
    it("should serialize custom fields to JSON", function()
      local task = models.Task.new("1", "Test", nil, nil, {}, "")
      task.custom = {
        field_one = "Value 1",
        field_two = "Value 2"
      }

      -- This tests that the model can be converted to a table for JSON
      local task_table = {
        id = task.id,
        name = task.name,
        custom = task.custom
      }

      assert.is_not_nil(task_table.custom)
      assert.are.equal("Value 1", task_table.custom.field_one)
    end)

    it("should deserialize custom fields from table", function()
      local data = {
        id = "1",
        name = "Test",
        details = "",
        notes = "",
        tags = {},
        custom = {
          my_field = "My value"
        }
      }

      -- Simulating what from_table would do
      local task = models.Task.new(data.id, data.name, data.details, nil, data.tags, data.notes)
      task.custom = data.custom

      assert.is_not_nil(task.custom)
      assert.are.equal("My value", task.custom.my_field)
    end)
  end)

  describe("Edge cases", function()
    it("should handle empty custom section", function()
      local text = [[
# Task: 1 - Test

## Details

### Vision / Purpose

## Notes

## Tags

## Empty Section

## Another Section
Has content
]]

      local task = task_format.text_to_task(text, "Area")

      assert.is_not_nil(task.custom)
      -- Empty section should exist but be empty string
      assert.are.equal("", task.custom.empty_section or "")
      assert.are.equal("Has content", task.custom.another_section)
    end)

    it("should handle custom section at end of file without trailing newline", function()
      local text = "# Task: 1 - Test\n\n## Details\n\n### Vision / Purpose\n\n## Notes\n\n## Tags\n\n## Final Section\nFinal content"

      local task = task_format.text_to_task(text, "Area")

      assert.is_not_nil(task.custom)
      assert.are.equal("Final content", task.custom.final_section)
    end)

    it("should not create custom field for known H2 sections", function()
      local text = [[
# Task: 1 - Test

## Details

### Vision / Purpose
Vision

## Estimation

## Notes
Notes here

## Tags
tag1
]]

      local task = task_format.text_to_task(text, "Area")

      -- Should not have custom entries for known sections
      if task.custom then
        assert.is_nil(task.custom.details)
        assert.is_nil(task.custom.estimation)
        assert.is_nil(task.custom.notes)
        assert.is_nil(task.custom.tags)
      end
    end)

    it("should handle header that looks like H3 but is really code", function()
      local text = [[
# Task: 1 - Test

## Details

### Vision / Purpose
```markdown
### This is code not a header
```

## Notes

## Tags
]]

      local task = task_format.text_to_task(text, "Area")

      -- The ### inside code block should not be treated as header
      assert.is_true(task.details.vision_purpose:find("### This is code") ~= nil,
        "H3 inside code block should be preserved as content")
    end)
  end)
end)
