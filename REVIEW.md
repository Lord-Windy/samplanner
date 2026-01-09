# Samplanner Code Review

## Overview

This is a well-structured Neovim plugin for project planning and time tracking, totaling approximately **6,300 lines of Lua code**. The architecture follows clean separation of concerns with domain, UI, and format layers.

## Summary of Findings

The codebase has solid architecture but contains significant redundancy that could reduce the code by **~25-30%** (roughly 1,500-1,900 lines) through consolidation of repeated patterns.

---

## Major Redundancy Issues

### 1. Duplicated `sorted_keys()` Function (~80 lines wasted)

The same sorting function appears **4 times** with nearly identical code:

| File | Lines |
|------|-------|
| `domain/operations.lua` | 285-297, 353-364, 493-504, 580-605 |
| `ui/tree.lua` | 21-45 |

**Recommendation:** Extract to a shared utility module:

```lua
-- lua/samplanner/utils/table.lua
local M = {}

function M.sorted_keys(t)
  local keys = {}
  for k in pairs(t) do
    table.insert(keys, k)
  end
  table.sort(keys, function(a, b)
    local a_parts = {}
    for part in a:gmatch("(%d+)") do
      table.insert(a_parts, tonumber(part))
    end
    local b_parts = {}
    for part in b:gmatch("(%d+)") do
      table.insert(b_parts, tonumber(part))
    end
    for i = 1, math.max(#a_parts, #b_parts) do
      if (a_parts[i] or 0) ~= (b_parts[i] or 0) then
        return (a_parts[i] or 0) < (b_parts[i] or 0)
      end
    end
    return false
  end)
  return keys
end

return M
```

**Savings:** ~60 lines

---

### 2. Repeated Section Parsing Pattern in `formats/task.lua` (~600 lines wasted)

The same "save previous section and switch to new section" pattern is repeated **~30 times**:

```lua
-- This exact pattern appears dozens of times (lines 194-218, 523-552, etc.)
if current_section == "outcome" and #section_lines > 0 then
  section_lines = normalize_empty_lines(section_lines)
  while #section_lines > 0 and section_lines[#section_lines] == "" do
    table.remove(section_lines)
  end
  while #section_lines > 0 and section_lines[1] == "" do
    table.remove(section_lines, 1)
  end
  jd.outcome_dod = table.concat(section_lines, "\n")
end
```

**Recommendation:** Create a helper function:

```lua
local function save_section_content(section_lines)
  section_lines = normalize_empty_lines(section_lines)
  while #section_lines > 0 and section_lines[#section_lines] == "" do
    table.remove(section_lines)
  end
  while #section_lines > 0 and section_lines[1] == "" do
    table.remove(section_lines, 1)
  end
  return table.concat(section_lines, "\n")
end
```

**Savings:** ~400 lines

---

### 3. Identical Section Content Parsing Logic (~400 lines wasted)

In `formats/task.lua`, lines 624-775 contain nearly identical parsing logic repeated for 7 different sections (outcome, requirements, dependencies, approach, risks, validation, and scope subsections):

```lua
-- This pattern repeats 7+ times
elseif current_section == "outcome" then
  if line == "" then
    if #section_lines > 0 then
      table.insert(section_lines, "")
    end
  elseif line:match("^  ") then
    local content = line:sub(3)
    table.insert(section_lines, content)
  elseif line:match("^%s+") then
    local content = line:match("^%s+(.*)$")
    if content and content ~= "" then
      table.insert(section_lines, content)
    end
  else
    table.insert(section_lines, line)
  end
```

**Recommendation:** Use a generic content capture function:

```lua
local function capture_indented_content(line, section_lines, indent_size)
  indent_size = indent_size or 2
  local pattern = "^" .. string.rep(" ", indent_size)

  if line == "" then
    if #section_lines > 0 then
      table.insert(section_lines, "")
    end
  elseif line:match(pattern) then
    table.insert(section_lines, line:sub(indent_size + 1))
  elseif line:match("^%s+") then
    local content = line:match("^%s+(.*)$")
    if content and content ~= "" then
      table.insert(section_lines, content)
    end
  else
    table.insert(section_lines, line)
  end
end
```

**Savings:** ~300 lines

---

### 4. Duplicate `update_ids()` Helper in `operations.lua` (~60 lines wasted)

The `update_ids()` function is defined twice with nearly identical logic:

- Lines 237-259 in `move_node()`
- Lines 444-462 in `swap_siblings()`

**Recommendation:** Extract to a shared local function at module level.

**Savings:** ~30 lines

---

### 5. Repeated Array-to-String Migration Logic in `models.lua` (~100 lines wasted)

The same pattern appears 20+ times:

```lua
self.outcome_dod = type(data.outcome_dod) == "table"
  and helpers.array_to_text(data.outcome_dod)
  or data.outcome_dod or ""
```

**Recommendation:** Create a helper function:

```lua
local function migrate_field(value, helpers)
  if type(value) == "table" then
    return helpers.array_to_text(value)
  end
  return value or ""
end
```

Then use: `self.outcome_dod = migrate_field(data.outcome_dod, helpers)`

**Savings:** ~60 lines

---

### 6. Repeated `if updates.field ~= nil` Blocks in `operations.lua` (~50 lines wasted)

Lines 680-700 and 838-873 contain repetitive field update patterns:

```lua
if updates.name ~= nil then
  task.name = updates.name
end
if updates.details ~= nil then
  task.details = updates.details
end
-- ... repeated 15+ times
```

**Recommendation:** Use a generic update function:

```lua
local function apply_updates(target, updates, fields)
  for _, field in ipairs(fields) do
    if updates[field] ~= nil then
      target[field] = updates[field]
    end
  end
end
```

**Savings:** ~40 lines

---

### 7. Similar `*_details_to_text()` Functions (~200 lines consolidatable)

`job_details_to_text()`, `component_details_to_text()`, and `area_details_to_text()` share similar patterns:

```lua
table.insert(lines, "Section Name")
if field and field ~= "" then
  for _, line in ipairs(split_lines(field)) do
    table.insert(lines, "  " .. line)
  end
else
  table.insert(lines, "  - ")
end
table.insert(lines, "")
```

**Recommendation:** Create a generic section formatter:

```lua
local function format_section(lines, header, content, indent)
  indent = indent or "  "
  table.insert(lines, header)
  if content and content ~= "" then
    for _, line in ipairs(split_lines(content)) do
      table.insert(lines, indent .. line)
    end
  else
    table.insert(lines, indent .. "- ")
  end
  table.insert(lines, "")
end
```

**Savings:** ~150 lines

---

### 8. Triplicate `validate_and_migrate_details()` Logic (~120 lines wasted)

In `models.lua` lines 430-553, the same validation and migration pattern is repeated for Job, Component, and Area with only field name differences.

**Recommendation:** Parameterize the function:

```lua
local detail_configs = {
  Job = {
    model = M.JobDetails,
    fields = {"context_why", "outcome_dod", "scope_in"}
  },
  Component = {
    model = M.ComponentDetails,
    fields = {"purpose", "capabilities", "acceptance_criteria"}
  },
  Area = {
    model = M.AreaDetails,
    fields = {"vision_purpose", "goals_objectives", "key_components"}
  },
}

local function validate_and_migrate_details(task_data, node_type, notes)
  local config = detail_configs[node_type] or detail_configs.Area
  local details = task_data.details

  if not details then
    return config.model.new(), notes
  end

  if type(details) == "table" then
    for _, field in ipairs(config.fields) do
      if details[field] ~= nil then
        return config.model.new(details), notes
      end
    end
    -- Migrate non-conforming table
    local detail_str = vim.inspect(details)
    notes = notes ~= "" and ("Migrated details:\n" .. detail_str .. "\n\n" .. notes) or ("Migrated details:\n" .. detail_str)
    return config.model.new(), notes
  end

  if type(details) == "string" and details ~= "" then
    notes = notes ~= "" and ("Migrated details:\n" .. details .. "\n\n" .. notes) or ("Migrated details:\n" .. details)
    return config.model.new(), notes
  end

  return config.model.new(), notes
end
```

**Savings:** ~80 lines

---

## Minor Issues

### 9. Unused Variables
- `context_lines` declared but not always used in parsing functions

### 10. Inconsistent Error Handling
Some functions return `nil, err` while others return `false, err`. Consider standardizing.

### 11. Magic Numbers
- Indent sizes (2, 4) hardcoded in multiple places
- Should be constants: `local SECTION_INDENT = 2`

---

## Actual Savings Achieved

After refactoring, the codebase was reduced from **~6,313 lines** to **~5,553 lines** - a reduction of **~760 lines (12%)**.

| Refactoring | Description |
|-------------|-------------|
| utils/table.lua | Shared `sorted_keys()` and `apply_updates()` |
| utils/parsing.lua | Shared parsing helpers for text formats |
| domain/operations.lua | Uses shared utilities, consolidated update_ids |
| domain/models.lua | Consolidated migration logic with `migrate_field()` |
| formats/task.lua | Major refactoring using parsing helpers |
| formats/session.lua | Uses shared parsing utilities |
| ui/tree.lua | Uses shared `sorted_keys()` |

The actual savings were less than initially estimated because:
1. Some parsing patterns required subtle variations that couldn't be fully abstracted
2. The scope subsections in task parsing needed special handling
3. Some redundancy was already somewhat acceptable given the different contexts

---

## Recommendations Priority

1. **High Impact:** Create `utils/table.lua` with shared `sorted_keys()`
2. **High Impact:** Create `utils/parsing.lua` with section parsing helpers
3. **Medium Impact:** Consolidate migration helpers in models
4. **Medium Impact:** Refactor text format functions to use generic helpers
5. **Low Impact:** Standardize error return patterns

---

## Architectural Strengths to Preserve

- Clean separation between domain, formats, and UI layers
- Well-documented function signatures with types
- Graceful degradation on malformed data
- Migration support for old data formats
- Modular buffer management

The codebase is well-architected overall. The main issue is excessive copy-paste of similar patterns rather than abstraction.
