# Array to String Migration

## Overview

This migration converts array fields in tasks and time sessions to newline-separated strings with bullet points. This makes it easier to support multi-paragraph content where needed.

## What Changed

### Task Fields (All converted from arrays to strings):

**JobDetails:**
- `outcome_dod`
- `scope_in`, `scope_out`
- `requirements_constraints`
- `dependencies`
- `approach`
- `risks`
- `validation_test_plan`

**ComponentDetails:**
- `capabilities`
- `acceptance_criteria`
- `architecture_design`
- `interfaces_integration`
- `quality_attributes`
- `related_components`

**AreaDetails:**
- `goals_objectives`
- `scope_boundaries`
- `key_components`
- `success_metrics`
- `stakeholders`
- `dependencies_constraints`

**Estimation:**
- `assumptions`
- `post_estimate_notes.could_be_smaller`
- `post_estimate_notes.could_be_bigger`
- `post_estimate_notes.ignored_last_time`

### TimeLog Fields:

- `deliverables`
- `blockers`
- `defects.found`, `defects.fixed`
- `retrospective.what_went_well`
- `retrospective.what_needs_improvement`
- `retrospective.lessons_learned`

**Note:** `TimeLog.tasks` remains an array since it's a list of task ID references.

## Format Examples

### Old Array Format:
```json
{
  "outcome_dod": ["Complete feature X", "Write tests", "Update docs"],
  "assumptions": ["API will be stable", "Resources available"]
}
```

### New String Format (Free-form):
```json
{
  "outcome_dod": "- Complete feature X\n- Write tests\n- Update docs",
  "assumptions": "- API will be stable\n- Resources available"
}
```

Or with paragraphs:
```json
{
  "outcome_dod": "- Complete feature X\n\nThis is a detailed paragraph explaining what completing feature X means.\nIt can span multiple lines.\n\n- Write tests\n- Update docs",
  "approach": "First, we need to understand the requirements.\n\nThen:\n- Design the solution\n- Implement it\n- Test thoroughly"
}
```

**Important**: The format is free-form. You can use bullets where helpful, write paragraphs where needed, or mix both. The text is preserved exactly as written.

## Automatic Migration

The data models automatically detect and convert old array formats to the new string format when loading JSON files. No manual migration is required for existing files.

### Example:
```lua
-- Old format in JSON: {"assumptions": ["item 1", "item 2"]}
local est = models.Estimation.new({assumptions = {"item 1", "item 2"}})
-- est.assumptions is now "- item 1\n- item 2"
```

## Manual Migration

If you want to migrate JSON files on disk, use the migration script:

```lua
local migrate = require('samplanner.migrations.migrate_json')

-- Convert arrays to strings (forward migration)
migrate.migrate_file_to_strings("path/to/project.json")

-- Convert strings back to arrays (reverse migration)
migrate.migrate_file_to_arrays("path/to/project.json")
```

## Updating Tests

Tests need to be updated to expect strings instead of arrays. Here's the pattern:

### Before:
```lua
local jd = models.JobDetails.new({outcome_dod = {"item 1", "item 2"}})
assert.are.same({"item 1", "item 2"}, jd.outcome_dod)  -- FAILS
```

### After:
```lua
local jd = models.JobDetails.new({outcome_dod = {"item 1", "item 2"}})
assert.are.equal("- item 1\n- item 2", jd.outcome_dod)  -- PASSES

-- Or use new string format directly:
local jd = models.JobDetails.new({outcome_dod = "- item 1\n- item 2"})
assert.are.equal("- item 1\n- item 2", jd.outcome_dod)  -- PASSES
```

### Pattern for Updating Tests:

1. Change `assert.are.same({}, field)` to `assert.are.equal("", field)` for empty checks
2. Change `assert.are.same({"item"}, field)` to `assert.are.equal("- item", field)` for single items
3. Change `assert.are.same({"item1", "item2"}, field)` to `assert.are.equal("- item1\n- item2", field)` for multiple items

## Benefits

1. **Easier multi-line content**: Each "item" can now contain paragraphs
2. **Simpler JSON structure**: Strings are simpler than arrays
3. **Same text editing experience**: The UI display format remains unchanged
4. **Backward compatible**: Old array format is automatically converted

## Text Display Format (Unchanged)

The text editing format remains the same:

```
Outcome / Definition of Done
  - Complete feature X
  - Write tests
  - Update docs
```

The conversion between internal representation (string) and display format (bullets) is handled automatically by the format converters.
