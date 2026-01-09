-- Unit tests for Markdown parsing utilities
-- Run with: luajit tests/unit/markdown_parsing_spec.lua
--
-- These tests define the expected behavior for the new Markdown formatting utilities.

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

local parsing = require('samplanner.utils.parsing')

describe("Markdown Parsing Utilities", function()
  describe("format_h1", function()
    it("should create H1 header", function()
      local result = parsing.format_h1("Title")
      assert.are.equal("# Title\n", result)
    end)

    it("should handle empty title", function()
      local result = parsing.format_h1("")
      assert.are.equal("# \n", result)
    end)
  end)

  describe("format_h2", function()
    it("should create H2 header", function()
      local result = parsing.format_h2("Section")
      assert.are.equal("## Section\n", result)
    end)

    it("should handle empty section name", function()
      local result = parsing.format_h2("")
      assert.are.equal("## \n", result)
    end)
  end)

  describe("format_h3", function()
    it("should create H3 header", function()
      local result = parsing.format_h3("Subsection")
      assert.are.equal("### Subsection\n", result)
    end)

    it("should handle empty subsection name", function()
      local result = parsing.format_h3("")
      assert.are.equal("### \n", result)
    end)
  end)

  describe("format_task_title", function()
    it("should format task title with ID and name", function()
      local result = parsing.format_task_title("1.2.3", "My Task")
      assert.are.equal("# Task: 1.2.3 - My Task\n", result)
    end)

    it("should handle empty name", function()
      local result = parsing.format_task_title("1", "")
      assert.are.equal("# Task: 1 - \n", result)
    end)

    it("should handle ID with dots", function()
      local result = parsing.format_task_title("1.2.3.4", "Deep Task")
      assert.are.equal("# Task: 1.2.3.4 - Deep Task\n", result)
    end)
  end)

  describe("format_md_section", function()
    it("should format section with H2 header and content", function()
      local lines = {}
      parsing.format_md_section(lines, "Details", "Some content here")

      local result = table.concat(lines, "\n")
      assert.is_true(result:find("## Details\n") ~= nil)
      assert.is_true(result:find("Some content here") ~= nil)
    end)

    it("should format section with empty content", function()
      local lines = {}
      parsing.format_md_section(lines, "Notes", "")

      local result = table.concat(lines, "\n")
      assert.is_true(result:find("## Notes\n") ~= nil)
    end)

    it("should format multiline content", function()
      local lines = {}
      parsing.format_md_section(lines, "Goals", "- Goal 1\n- Goal 2\n- Goal 3")

      local result = table.concat(lines, "\n")
      assert.is_true(result:find("## Goals\n") ~= nil)
      assert.is_true(result:find("- Goal 1\n") ~= nil)
      assert.is_true(result:find("- Goal 2\n") ~= nil)
    end)
  end)

  describe("format_md_subsection", function()
    it("should format subsection with H3 header and content", function()
      local lines = {}
      parsing.format_md_subsection(lines, "Vision / Purpose", "Our vision")

      local result = table.concat(lines, "\n")
      assert.is_true(result:find("### Vision / Purpose\n") ~= nil)
      assert.is_true(result:find("Our vision") ~= nil)
    end)

    it("should format subsection with empty content", function()
      local lines = {}
      parsing.format_md_subsection(lines, "Other", "")

      local result = table.concat(lines, "\n")
      assert.is_true(result:find("### Other\n") ~= nil)
    end)
  end)

  describe("format_gfm_checkbox", function()
    it("should format checked checkbox", function()
      local result = parsing.format_gfm_checkbox(true, "New work")
      assert.are.equal("- [x] New work", result)
    end)

    it("should format unchecked checkbox", function()
      local result = parsing.format_gfm_checkbox(false, "Change")
      assert.are.equal("- [ ] Change", result)
    end)
  end)

  describe("format_gfm_checkbox_group", function()
    it("should format vertical checkbox group", function()
      local options = {
        { label = "New work", value = "new_work" },
        { label = "Change", value = "change" },
        { label = "Bugfix", value = "bugfix" },
      }
      local result = parsing.format_gfm_checkbox_group(options, "change")

      assert.is_true(result:find("%- %[ %] New work\n") ~= nil)
      assert.is_true(result:find("%- %[x%] Change\n") ~= nil)
      assert.is_true(result:find("%- %[ %] Bugfix") ~= nil)
    end)

    it("should handle no selection", function()
      local options = {
        { label = "Low", value = "low" },
        { label = "Med", value = "med" },
        { label = "High", value = "high" },
      }
      local result = parsing.format_gfm_checkbox_group(options, "")

      assert.is_true(result:find("%- %[ %] Low\n") ~= nil)
      assert.is_true(result:find("%- %[ %] Med\n") ~= nil)
      assert.is_true(result:find("%- %[ %] High") ~= nil)
    end)
  end)

  describe("parse_h1_task_header", function()
    it("should parse task ID and name from H1", function()
      local id, name = parsing.parse_h1_task_header("# Task: 1.2.3 - My Task Name")
      assert.are.equal("1.2.3", id)
      assert.are.equal("My Task Name", name)
    end)

    it("should handle name with hyphens", function()
      local id, name = parsing.parse_h1_task_header("# Task: 1 - Task - With - Hyphens")
      assert.are.equal("1", id)
      assert.are.equal("Task - With - Hyphens", name)
    end)

    it("should return nil for non-matching line", function()
      local id, name = parsing.parse_h1_task_header("## Not a task header")
      assert.is_nil(id)
      assert.is_nil(name)
    end)

    it("should handle empty name", function()
      local id, name = parsing.parse_h1_task_header("# Task: 1 - ")
      assert.are.equal("1", id)
      assert.are.equal("", name)
    end)
  end)

  describe("is_h2_header", function()
    it("should detect H2 header", function()
      local is_h2, title = parsing.is_h2_header("## Details")
      assert.is_true(is_h2)
      assert.are.equal("Details", title)
    end)

    it("should not match H1", function()
      local is_h2, title = parsing.is_h2_header("# Not H2")
      assert.is_false(is_h2)
      assert.is_nil(title)
    end)

    it("should not match H3", function()
      local is_h2, title = parsing.is_h2_header("### Not H2")
      assert.is_false(is_h2)
      assert.is_nil(title)
    end)

    it("should handle header with trailing space", function()
      local is_h2, title = parsing.is_h2_header("## Notes ")
      assert.is_true(is_h2)
      assert.are.equal("Notes", title)
    end)
  end)

  describe("is_h3_header", function()
    it("should detect H3 header", function()
      local is_h3, title = parsing.is_h3_header("### Vision / Purpose")
      assert.is_true(is_h3)
      assert.are.equal("Vision / Purpose", title)
    end)

    it("should not match H2", function()
      local is_h3, title = parsing.is_h3_header("## Not H3")
      assert.is_false(is_h3)
      assert.is_nil(title)
    end)

    it("should not match H4", function()
      local is_h3, title = parsing.is_h3_header("#### Not H3")
      assert.is_false(is_h3)
      assert.is_nil(title)
    end)
  end)

  describe("parse_gfm_checkbox_value", function()
    it("should detect checked checkbox and extract value", function()
      local options = {
        { pattern = "New work", value = "new_work" },
        { pattern = "Change", value = "change" },
        { pattern = "Bugfix", value = "bugfix" },
      }

      local result = parsing.parse_gfm_checkbox_value("- [x] Change", options)
      assert.are.equal("change", result)
    end)

    it("should detect checked checkbox with X (uppercase)", function()
      local options = {
        { pattern = "New work", value = "new_work" },
      }

      local result = parsing.parse_gfm_checkbox_value("- [X] New work", options)
      assert.are.equal("new_work", result)
    end)

    it("should return nil for unchecked checkbox", function()
      local options = {
        { pattern = "Low", value = "low" },
      }

      local result = parsing.parse_gfm_checkbox_value("- [ ] Low", options)
      assert.is_nil(result)
    end)

    it("should return nil for non-checkbox line", function()
      local options = {
        { pattern = "Test", value = "test" },
      }

      local result = parsing.parse_gfm_checkbox_value("Just text", options)
      assert.is_nil(result)
    end)
  end)

  describe("existing utilities still work", function()
    it("checkbox should still create old format", function()
      assert.are.equal("[x]", parsing.checkbox(true))
      assert.are.equal("[ ]", parsing.checkbox(false))
    end)

    it("normalize_empty_lines should collapse multiple empty lines", function()
      local lines = {"a", "", "", "", "b", "", "c"}
      local result = parsing.normalize_empty_lines(lines)
      assert.are.same({"a", "", "b", "", "c"}, result)
    end)

    it("split_lines should preserve empty lines", function()
      local result = parsing.split_lines("a\n\nb\nc")
      assert.are.same({"a", "", "b", "c"}, result)
    end)

    it("finalize_section should trim and normalize", function()
      local lines = {"", "a", "", "", "b", ""}
      local result = parsing.finalize_section(lines)
      assert.are.equal("a\n\nb", result)
    end)
  end)
end)
