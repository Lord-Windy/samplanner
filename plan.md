# Samplanner Implementation Plan

## Current State

The project has a solid foundation with:
- **init.lua**: Plugin setup with basic configuration
- **domain/models.lua**: Core data models (ProjectInfo, Task, StructureNode, TimeLog, Project)
- **ports/storage.lua**: Abstract storage interface
- **ports/file_storage.lua**: File-based JSON storage implementation

## Phase 1: Core Domain Functions

### 1.1 Project Management
- [x] `create_project(id, name)` - Create a new project and save to storage
- [x] `load_project(name)` - Load existing project from storage
- [x] `delete_project(name)` - Remove project from storage

### 1.2 Tree Structure Operations
- [x] `add_node(project, parent_id, node_type, name)` - Add node at any position in tree
- [x] `remove_node(project, node_id)` - Remove node and its children
- [x] `move_node(project, node_id, new_parent_id)` - Relocate node in tree
- [x] `renumber_structure(project)` - Re-number all nodes for consistent ordering
- [x] `get_tree_display(project)` - Render tree as formatted string for display

### 1.3 Task Management
- [x] `create_task(project, id, name, details, estimation, tags)` - Create detailed task
- [x] `update_task(project, id, updates)` - Modify existing task
- [x] `delete_task(project, id)` - Remove task from task_list
- [x] `link_task_to_node(project, task_id, node_id)` - Associate task with structure node

### 1.4 Time Log Operations
- [x] `start_session(project)` - Create new TimeLog with start_timestamp
- [x] `stop_session(project, session_index)` - Set end_timestamp on active session
- [x] `update_session(project, session_index, updates)` - Modify session notes/interruptions
- [x] `add_task_to_session(project, session_index, task_id)` - Link task to session
- [x] `get_active_session(project)` - Find session without end_timestamp

### 1.5 Tag Operations
- [x] `add_tag(project, tag)` - Add tag to project's tag list
- [x] `remove_tag(project, tag)` - Remove tag from project
- [x] `tag_task(project, task_id, tag)` - Add tag to specific task
- [x] `untag_task(project, task_id, tag)` - Remove tag from task
- [x] `search_by_tag(project, tag)` - Find all tasks with given tag
- [x] `search_by_tags(project, tags, match_all)` - Find tasks matching multiple tags

## Phase 2: Text Format Conversion

### 2.1 Session Format
Human-readable format for time logs:
```
── Session ──────────────────────────
Start: 2024-01-15 09:00
End:   2024-01-15 10:30

── Notes ────────────────────────────
(notes here)

── Interruptions (minutes: 15) ──────
(interruptions here)

── Tasks ────────────────────────────
- task_001
- task_002
```

- [x] `session_to_text(time_log)` - Convert TimeLog to editable text format
- [x] `text_to_session(text)` - Parse text back to TimeLog (simple regex parsing)

### 2.2 Task Format
Human-readable format for tasks:
```
── Task: task_001 ───────────────────
Name: Implement feature X

── Details ──────────────────────────
(description here)

── Estimation ───────────────────────
(estimation here)

── Tags ─────────────────────────────
tag1, tag2, tag3
```

- [x] `task_to_text(task)` - Convert Task to editable text format
- [x] `text_to_task(text)` - Parse text back to Task

### 2.3 Structure Format
Tree display format:
```
1 Area: Authentication
  1.1 Component: Login Flow
    1.1.1 Job: Create login form
    1.1.2 Job: Add validation
  1.2 Component: Session Management
2 Area: Dashboard
```

- [x] `structure_to_text(structure)` - Render tree as indented text
- [x] `text_to_structure(text)` - Parse indented text back to structure

## Phase 3: Neovim UI Layer

### 4.1 Buffer Management
- [x] Create `ui/buffers.lua` - Buffer creation and management
- [x] `create_session_buffer(project, session_index)` - Open session in editable buffer
- [x] `create_task_buffer(project, task_id)` - Open task in editable buffer
- [x] `create_structure_buffer(project)` - Open tree view buffer
- [x] Auto-save on `:w` using BufWriteCmd autocmd
- [x] Auto-parse buffer content back to model on save

### 4.2 Tree View
- [x] Create `ui/tree.lua` - Tree view rendering and interaction
- [x] Display collapsible tree structure
- [x] Keybindings for tree manipulation:
  - `a` - Add child node
  - `A` - Add sibling node
  - `d` - Delete node
  - `r` - Rename node
  - `<CR>` - Open task details
  - `zo/zc` - Expand/collapse

### 4.3 Tag Interface
- [x] Create `ui/tags.lua` - Tag management UI
- [x] `open_tag_picker(callback)` - Fuzzy picker for existing tags
- [x] `add_tag_prompt(task_id)` - Prompt to add new or existing tag
- [x] `show_tag_search()` - Filter tasks by selected tags

### 4.4 Session Timer
- [x] Create `ui/timer.lua` - Time tracking UI
- [x] `:SamplannerStart` - Start new session
- [x] `:SamplannerStop` - Stop current session
- [x] `:SamplannerSession` - Open current session buffer
- [x] Status line integration showing elapsed time

## Phase 5: Plugin Commands

### 5.1 Core Commands
- [x] `:Samplanner` - Open project picker or current project
- [x] `:SamplannerNew <name>` - Create new project
- [x] `:SamplannerLoad <name>` - Load existing project
- [x] `:SamplannerTree` - Open tree structure view
- [x] `:SamplannerTask <id>` - Open task by ID
- [x] `:SamplannerTags` - Open tag management

### 5.2 Session Commands
- [x] `:SamplannerStart` - Start time tracking session
- [x] `:SamplannerStop` - Stop current session
- [x] `:SamplannerSession [index]` - Open session buffer
- [x] `:SamplannerSessions` - List all sessions

### 5.3 Search Commands
- [x] `:SamplannerSearch <query>` - Search tasks by text
- [x] `:SamplannerByTag <tag>` - Filter tasks by tag

## Implementation Order

1. **Phase 1.1-1.3** - Core project, tree, and task operations
2. **Phase 2.1-2.3** - Text format converters (enables manual editing)
3. **Phase 4.1** - Basic buffer management
4. **Phase 1.4-1.5** - Time logs and tags
5. **Phase 4.2** - Tree view UI
6. **Phase 4.3-4.4** - Tag and timer UI
7. **Phase 4** - Plugin commands

## File Structure Target

```
lua/samplanner/
├── init.lua                 # Plugin entry, setup, commands
├── domain/
│   ├── models.lua           # Data models (exists)
│   └── operations.lua       # Core business logic
├── ports/
│   ├── storage.lua          # Storage interface (exists)
│   └── file_storage.lua     # File implementation (exists)
├── formats/
│   ├── session.lua          # Session text format
│   ├── task.lua             # Task text format
│   └── structure.lua        # Tree text format
└── ui/
    ├── buffers.lua          # Buffer management
    ├── tree.lua             # Tree view
    ├── tags.lua             # Tag picker/search
    └── timer.lua            # Session timer
```

## Notes

- All operations should save automatically after modification
- Consider telescope.nvim integration for fuzzy finding
- Tree view could use nvim-tree style folding
