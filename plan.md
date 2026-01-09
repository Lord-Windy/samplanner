# Plan: Migrate Content Format to Markdown

## Overview

Convert Samplanner's bespoke text format to standard Markdown, using:
- **H1 (`#`)** for task identification
- **H2 (`##`)** for section headers

This will improve compatibility with external tools, syntax highlighting, and readability.

---

## Current Format

```
── Task: 1.1.1 ───────────────────
Task Name Here

── Details ──────────────────────────
Purpose / What It Is
[content]

Goals / Objectives
  - Item 1
  - Item 2

── Estimation ───────────────────────
Type
  [x] New work   [ ] Change   [ ] Bugfix

── Notes ────────────────────────────
[freeform content]
```

---

## Target Markdown Format

```markdown
# Task: 1.1.1 - Task Name Here

## Details

### Purpose / What It Is
[content]

### Goals / Objectives
- Item 1
- Item 2

## Estimation

### Type
- [x] New work
- [ ] Change
- [ ] Bugfix

## Notes
[freeform content]
```

---

## Files to Modify

### 1. `lua/samplanner/formats/task.lua`
Main converter for task content display and parsing.

**Changes:**
- `task_to_text()`: Replace `format_section()` calls with Markdown headers
- `text_to_task()`: Update parsing to recognize `#`, `##`, `###` headers
- Update all task type handlers (Area, Component, Job)

### 2. `lua/samplanner/utils/parsing.lua`
Utility functions for text processing.

**Changes:**
- `format_section()`: Change to emit `## Section Name` instead of `── Section ──`
- Add new `format_subsection()` for H3 headers (`###`)
- Update section detection patterns from `^──` to `^##`
- Keep checkbox utilities (`[x]`/`[ ]`) - these are GFM compatible

### 3. `lua/samplanner/formats/session.lua`
Session/time log formatting.

**Changes:**
- Convert session headers to H2 format
- Update parsing to match new header patterns

### 4. `lua/samplanner/formats/structure.lua` (minimal changes)
Tree structure rendering - mostly independent of content format.

**Changes:**
- Review if any section formatting is used here (likely none)

---

## Detailed Changes

### Phase 1: Update Parsing Utilities

**File:** `lua/samplanner/utils/parsing.lua`

1. Modify `format_section(header, content)`:
   ```lua
   -- Old: return "── " .. header .. " ──────────────────\n" .. content
   -- New: return "## " .. header .. "\n" .. content
   ```

2. Add `format_subsection(header, content)`:
   ```lua
   return "### " .. header .. "\n" .. content
   ```

3. Add `format_title(task_id, name)`:
   ```lua
   return "# Task: " .. task_id .. " - " .. name .. "\n"
   ```

4. Update section detection patterns in any parsing functions

### Phase 2: Update Task Formatter

**File:** `lua/samplanner/formats/task.lua`

1. Update `task_to_text()`:
   - Start with H1: `# Task: {id} - {name}`
   - Each major section becomes H2: `## Details`, `## Estimation`, `## Notes`, `## Tags`
   - Sub-sections within Details become H3: `### Vision / Purpose`, `### Goals / Objectives`

2. Update `text_to_task()`:
   - Parse H1 for task ID and name
   - Parse H2 for major sections
   - Parse H3 for sub-sections within Details
   - Handle content between headers

3. Update detail formatters for each task type:
   - `format_area_details()` / `parse_area_details()`
   - `format_component_details()` / `parse_component_details()`
   - `format_job_details()` / `parse_job_details()`

### Phase 3: Update Session Formatter

**File:** `lua/samplanner/formats/session.lua`

1. Update `session_to_text()`:
   - Use H2 for: `## Session`, `## Productivity Metrics`, `## Deliverables`, etc.

2. Update `text_to_session()`:
   - Match against `^## ` pattern instead of `^── `

### Phase 4: Checkbox Format Decision

**Option A: Keep inline checkboxes (current)**
```
- [x] New work   [ ] Change   [ ] Bugfix
```

**Option B: Convert to GFM task list format**
```
- [x] New work
- [ ] Change
- [ ] Bugfix
```

Recommendation: **Option B** - More standard Markdown, better rendering in external viewers.

---

## Migration Considerations

### Backwards Compatibility
- Existing saved projects use JSON storage (not the text format)
- Text format is transient (only in buffers)
- No migration needed for stored data

### Syntax Highlighting
- Set buffer filetype to `markdown` for proper highlighting
- Current: Custom filetype `samplanner`
- May need to update `ui/buffers.lua` to set `filetype = "markdown"`

### Testing
- Verify round-trip: JSON -> Markdown -> edit -> parse -> JSON
- Test all three task types: Area, Component, Job
- Test session format
- Verify no data loss in complex nested content

---

## Open Questions

1. **H3 for sub-sections?** Should we use H3 (`###`) for sub-sections within Details, or keep them as bold text / other formatting?

Yes H3 for sub sections is awesome

2. **Checkbox layout?** Keep inline (compact) or switch to vertical list (more standard)?

Option B style

3. **Code blocks?** Should freeform text areas use code blocks or remain plain?

Free form text should remain free form because a big reason to move to
this is so I CAN use code blocks

4. **Frontmatter?** Consider YAML frontmatter for metadata instead of H1 for task info?

No - stick with H1 for simplicity

---

## Implementation Order

1. Update `parsing.lua` utilities first (foundation)
2. Update `task.lua` (largest change)
3. Update `session.lua`
4. Update buffer filetype in `buffers.lua`
5. Test all task types and session format
6. Address any edge cases discovered during testing
