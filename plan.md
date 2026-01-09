# Dynamic Object Creation from Markdown Headers

## Goal

When saving a buffer that contains additional `##` or `###` headers beyond the predefined ones, automatically create new fields in the object table. This leverages Lua's dynamic table nature where keys can be added at runtime.

## Header Level Rules

| Level | Syntax | Behavior |
|-------|--------|----------|
| H1 | `#` | **Never saved as custom** - content gets moved to notes |
| H2 | `##` | Creates new top-level custom fields |
| H3 | `###` | Creates new custom fields (within current section context) |
| H4+ | `####` etc. | Treated as plain text, not parsed as headers |

This means the parser only recognizes `##` and `###` as structural markers. Anything with 4+ hashes is just content.

## Current State

- `formats/task.lua` parses Markdown with a state machine that recognizes specific H2 sections: `Details`, `Estimation`, `Notes`, `Tags`
- H3 headers are parsed within those sections for known fields (e.g., `Context / Why`, `Approach`, etc.)
- Unknown headers are currently ignored
- Data models in `domain/models.lua` have fixed fields (JobDetails, ComponentDetails, AreaDetails)

## Proposed Design

### 1. Add a dynamic `custom` table to Task model

In `domain/models.lua`, extend the Task structure:

```lua
Task = {
  id: string,
  name: string,
  details: JobDetails | ComponentDetails | AreaDetails,
  estimation: Estimation | nil,
  notes: string,
  tags: [string],
  custom: {[string]: string}  -- NEW: dynamic key-value pairs from unknown headers
}
```

### 2. Modify parsing to capture unknown headers

In `formats/task.lua`, update `text_to_task()`:

- **H1 (`#`)**: If encountered (other than the task header), append content to `notes`
- **H2 (`##`)**: Known sections parsed normally; unknown sections → `custom[key]`
- **H3 (`###`)**: Known subsections parsed normally; unknown subsections → nested in current section's custom
- **H4+ (`####`...)**: Treated as plain text content, not structural

```lua
-- Pseudocode for header handling
local known_h2 = { Details = true, Estimation = true, Notes = true, Tags = true }

-- H1 handling (except task header line)
if line:match("^# [^#]") and not parsing.parse_h1_task_header(line) then
  -- Stray H1 content goes to notes
  append_to_notes(line)
end

-- H2 handling
if is_h2 and not known_h2[h2_title] then
  current_section = "custom"
  current_custom_key = normalize_key(h2_title)  -- e.g., "My Section" → "my_section"
end

-- H4+ treated as content (no special handling needed - just don't match them)
-- The existing is_h2_header and is_h3_header patterns already exclude these
```

### 3. Key normalization function

Create a utility to convert header text to valid Lua table keys:

```lua
function normalize_header_to_key(header)
  return header
    :lower()
    :gsub("[^%w%s]", "")  -- Remove special chars
    :gsub("%s+", "_")      -- Spaces to underscores
    :gsub("^_+", "")       -- Trim leading underscores
    :gsub("_+$", "")       -- Trim trailing underscores
end
```

### 4. Serialize custom fields back to Markdown

In `task_to_text()`, append custom sections after the standard ones:

```lua
-- After rendering Notes and Tags sections
if task.custom and next(task.custom) then
  for key, value in pairs(task.custom) do
    table.insert(lines, "")
    table.insert(lines, "## " .. key_to_header(key))
    table.insert(lines, "")
    table.insert(lines, value)
  end
end
```

### 5. Persist custom fields to JSON

Update `ports/file_storage.lua` serialization:

- `project_to_table()` should include `task.custom` when present
- `models.Project.from_table()` should reconstruct `custom` from stored JSON

## Implementation Steps

1. **Add `custom` field to Task model** in `domain/models.lua`
   - Update `Task.new()` constructor
   - Update `Task.from_table()` migration

2. **Add key normalization utilities** in `utils/parsing.lua`
   - `normalize_header_to_key(header)`
   - `key_to_header(key)` (reverse for display)

3. **Update parser** in `formats/task.lua`
   - Modify `text_to_task()` to capture unknown H2 headers
   - Optionally capture unknown H3 headers within Details

4. **Update formatter** in `formats/task.lua`
   - Modify `task_to_text()` to render custom sections

5. **Update serialization** in `ports/file_storage.lua`
   - Ensure `custom` is included in JSON output
   - Handle loading projects with custom fields

6. **Add tests** for the new functionality

## Alternative: Fully Dynamic Details

Instead of a separate `custom` table, make `details` itself a dynamic table with no fixed schema. This is more flexible but loses type safety for known fields.

```lua
-- Option A: Mixed approach (recommended)
details = { purpose = "...", custom = { extra_field = "..." } }

-- Option B: Fully dynamic
details = { purpose = "...", extra_field = "..." }
```

Option A is recommended because it preserves the structured fields for known sections while allowing extensions.

## Open Questions

- Should unknown H3 headers within `## Details` become custom fields on the details object, or top-level custom fields?
- Should custom fields have any validation or constraints?
- Should the UI provide a way to "promote" a custom field to a known field?
- When an H1 is moved to notes, should it be stripped of the `#` prefix or preserved as-is?
