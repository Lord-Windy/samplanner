# Samplanner

A Neovim plugin for project planning and time tracking.

## Installation

Add the plugin to your Neovim configuration and call the setup function:

```lua
require('samplanner').setup({
  filepath = "/path/to/your/projects",  -- Where projects are stored
})
```

## Commands

### Core Project Commands

| Command | Description |
|---------|-------------|
| `:Samplanner` | Open project picker or current project tree view |
| `:SamplannerNew [name]` | Create a new project |
| `:SamplannerLoad [name]` | Load an existing project |
| `:SamplannerTree` | Open hierarchical tree structure view |
| `:SamplannerReload` | Reload current project from disk |

#### `:Samplanner`

Opens the main Samplanner interface. If a project is already loaded, it
displays the tree view. Otherwise, it shows a picker to select from
available projects.

#### `:SamplannerNew [name]`

Creates a new project. If a name is provided as an argument, creates the
project immediately. Otherwise, prompts for a project name via an input
dialog.

#### `:SamplannerLoad [name]`

Loads an existing project from disk. Supports autocomplete for project
names. If no name is provided, shows a picker with all available projects.

#### `:SamplannerTree`

Opens a vertical split displaying the hierarchical structure of the
current project. Requires a project to be loaded first.

#### `:SamplannerReload`

Refreshes the in-memory project state from the saved file on disk. Useful
when the project file has been modified externally.

---

### Task Management Commands

| Command | Description |
|---------|-------------|
| `:SamplannerTask [task_id]` | Open a task by ID |
| `:SamplannerTags` | Open tag management interface |

#### `:SamplannerTask [task_id]`

Opens a task in a buffer for viewing and editing. Supports autocomplete
for task IDs. If no ID is provided, shows a picker with all tasks in the
project.

#### `:SamplannerTags`

Opens the tag management UI for creating, editing, and managing task tags
within the current project.

---

### Session/Time Tracking Commands

| Command | Description |
|---------|-------------|
| `:SamplannerStart` | Start a time tracking session |
| `:SamplannerStop` | Stop the current session |
| `:SamplannerSession [index]` | Open a specific session |
| `:SamplannerSessions` | List all sessions |

#### `:SamplannerStart`

Begins a new time tracking session by creating a time log entry with the
current timestamp. Use this when you start working on your project.

#### `:SamplannerStop`

Closes the active time tracking session by setting its end timestamp. Use
this when you finish working.

#### `:SamplannerSession [index]`

Opens a specific session buffer for viewing. If an index is provided,
opens that session directly. Otherwise, opens the active session or shows
a picker if no session is active.

#### `:SamplannerSessions`

Opens a session picker to browse and select from all recorded time
tracking sessions.

---

### Search and Filter Commands

| Command | Description |
|---------|-------------|
| `:SamplannerSearch [query]` | Search tasks by text |
| `:SamplannerByTag [tag]` | Filter tasks by tag |

#### `:SamplannerSearch [query]`

Searches through task IDs, names, and details for matching text. Shows
results in a picker. If no query is provided, prompts for a search term.

#### `:SamplannerByTag [tag]`

Filters and displays tasks that have the specified tag. Supports
autocomplete for existing tags in the project. If no tag is provided,
shows a tag picker.

---

## Project Structure

Projects are stored as JSON files in the configured `filepath` directory.
Each project contains:

- **Tree Structure**: Hierarchical organization of milestones, features, and tasks
- **Tasks**: Individual work items with descriptions, estimations, and tags
- **Time Logs**: Session records for time tracking
- **Tags**: Labels for categorizing tasks

## License

Apache 2.0
