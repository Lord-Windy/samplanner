# Samplanner Concepts

## What is Samplanner?

Samplanner is a Neovim plugin for project planning and time tracking. It
provides a structured approach to managing projects through a hierarchical task
system with integrated time logging capabilities.

The core philosophy is to organize work in a three-tier hierarchy that mirrors
how software projects are naturally structured: strategic domains (Areas),
functional components (Components), and concrete work items (Jobs).

## Core Concepts

### 1. Hierarchical Structure

Samplanner organizes work using a three-tier hierarchy:

```
Area (1)
├── Component (1.1)
│   ├── Job (1.1.1)
│   └── Job (1.1.2)
└── Component (1.2)
    └── Job (1.2.1)
```

#### **Area** - Strategic Domain

The highest level of organization representing a major domain or feature area
of your project.

**Contains:**
- Vision/Purpose: Why this area exists
- Goals: What you're trying to achieve
- Scope: What's included and excluded
- Key Components: Overview of main parts
- Success Metrics: How you'll measure completion
- Stakeholders: Who cares about this area

**Example:** "Authentication System", "Dashboard", "API Layer"

#### **Component** - Functional Building Block
A functional unit within an Area that provides specific capabilities.

**Contains:**
- Purpose: What this component does
- Capabilities: Features it provides
- Acceptance Criteria: When it's considered complete
- Architecture: Technical design overview
- Interfaces: How it connects to other parts
- Quality Attributes: Performance, security requirements

**Example:** "Login Flow", "Session Management", "Password Reset"

#### **Job** - Concrete Work Item

The actual work to be done. Only Jobs can be marked as completed and have time
tracked against them.

**Contains:**
- Context: Background and motivation
- Outcomes: What success looks like
- Scope: What's in and out
- Requirements: Must-haves and constraints
- Dependencies: What needs to happen first
- Approach: How you'll tackle it
- Risks: What could go wrong
- Validation: How you'll verify it works

**Estimation Data (Jobs only):**
- Work Type: Development, research, bug fix, etc.
- Effort: Estimated time
- Confidence: How certain the estimate is
- Schedule: When it's planned
- Post-Estimate Notes: Actual results vs. estimates

### 2. Numbering System

Nodes are automatically numbered hierarchically to show relationships:

```
1        (Area)
1.1      (Component under Area 1)
1.1.1    (Job under Component 1.1)
1.1.2    (Job under Component 1.1)
1.2      (Component under Area 1)
2        (Area)
2.1      (Component under Area 2)
```

The numbering automatically updates when you add, remove, or move nodes in the
tree.

### 3. Structure vs. Tasks

**Key Design Decision:** The structure (tree hierarchy) and tasks (detailed
information) are separated.

- **Structure**: The organizational tree showing Areas, Components, and Jobs
  with their hierarchical relationships
- **Task List**: A flat map storing the detailed information for each node
  (name, details, estimation, tags, notes)

They're linked by ID. This separation allows:
- Fast tree operations without loading all task details
- Efficient rendering of the tree view
- Flexible data organization

### 4. Time Tracking

Time is tracked through **TimeLog** sessions:

```
Session {
  start_time: timestamp
  end_time: timestamp (optional, set when stopped)
  notes: session description
  interruptions: list of interruptions with minutes
  linked_tasks: tasks worked on during session
  session_metadata: tags, focus_level, context
}
```

**Workflow:**
1. Start a session with `:SamplannerStart`
2. Timer shows elapsed time in status line
3. Work on tasks
4. Stop session with `:SamplannerStop`
5. Edit session later to add notes, interruptions, and link tasks

**Interruptions** track breaks and context switches, helping understand actual
focused time vs. elapsed time.

### 5. Tags

Tags provide flexible categorization across the hierarchy:

- Applied at any level (Area, Component, or Job)
- Used for filtering and searching
- Stored in task metadata
- Project maintains a master tag list

**Common uses:**
- Priority levels: `urgent`, `high-priority`
- Categories: `frontend`, `backend`, `infrastructure`
- Status: `blocked`, `waiting-review`
- Sprints: `sprint-1`, `sprint-2`

### 6. Task States

Jobs (only) can be marked as completed:
- `completed: false` - Active job (shows in tree normally)
- `completed: true` - Finished job (can be hidden with filter)

Areas and Components don't have completion status; they're organizational
containers.

## Data Model

### Project Structure

```lua
Project {
  project_info: {
    id: unique identifier
    name: project display name
  }

  structure: {
    -- Hierarchical tree of StructureNodes
    -- Each node has: id, type (Area|Component|Job), name, subtasks
  }

  task_list: {
    -- Flat map of task details by ID
    [task_id]: {
      name: string
      details: type-specific structured details
      estimation: effort/confidence data (Jobs only)
      tags: array of tags
      notes: additional context
      completed: boolean (Jobs only)
    }
  }

  time_log: [
    -- Array of time tracking sessions
    { start_time, end_time, notes, interruptions, linked_tasks, ... }
  ]

  tags: [
    -- Project-wide tag list
    "tag1", "tag2", ...
  ]
}
```

### Structured Details

Each node type has specific structured details:

**AreaDetails:**
- Vision/Purpose
- Goals
- Scope
- Key Components
- Success Metrics
- Stakeholders

**ComponentDetails:**
- Purpose
- Capabilities
- Acceptance Criteria
- Architecture
- Interfaces
- Quality Attributes

**JobDetails:**
- Context
- Outcomes
- Scope
- Requirements
- Dependencies
- Approach
- Risks
- Validation

This structure ensures you think through all aspects of work at each level.

## Architecture

### Layers

```
┌─────────────────────────────────────────┐
│           UI Layer (Neovim)             │
│  - Tree view (collapsible hierarchy)    │
│  - Task buffers (human-readable text)   │
│  - Session buffers (time log editing)   │
│  - Timer (status line integration)      │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────▼──────────────────────┐
│         Application Layer               │
│  - Command handlers                     │
│  - State management                     │
│  - Event coordination                   │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────▼──────────────────────┐
│          Domain Layer                   │
│  - Business logic (operations.lua)      │
│  - Data models (models.lua)             │
│  - Pure functions, no UI/storage        │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────▼──────────────────────┐
│      Ports Layer (Interfaces)           │
│  - Storage abstraction                  │
│  - Defines contracts                    │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────▼──────────────────────┐
│       Adapters Layer                    │
│  - JSON file storage implementation     │
│  - Could add: SQLite, remote sync, etc. │
└─────────────────────────────────────────┘
```

This is a **Ports and Adapters** (Hexagonal) architecture, which provides:
- **Testable**: Business logic is pure and independent
- **Flexible**: Easy to swap storage or add new UIs
- **Clear**: Each layer has a single responsibility
- **Maintainable**: Changes in one layer don't cascade

### Text Format Conversion

The plugin converts between structured data (Lua tables) and human-readable
text for editing.

**Task Format:**
```
── Task: 1.1.1 ───────────────────
Name: Create login form
── Details ──────────────────────
Context: Users need to authenticate
Outcomes: Functional login form
...
── Estimation ───────────────────
Work type: Development
Effort: 4 hours
...
── Tags ─────────────────────────
frontend, auth, sprint-1
```

When you save (`:w`), the text is parsed back into structured data and
persisted to JSON.

### Storage

Projects are stored as JSON files:

```
~/Dropbox/planning/
├── my-project.json
├── another-project.json
└── ...
```

Each file contains the complete project state. The JSON format allows:
- Manual editing outside Neovim if needed
- Version control (commit your plans!)
- Easy backup and sync (Dropbox, Git, etc.)
- Transparency (inspect data structure anytime)

## Workflows

### Starting a New Project

1. `:SamplannerNew project-name` - Creates new project
2. Tree view opens with empty structure
3. Press `a` to add Areas
4. Navigate and press `a` to add Components under Areas
5. Navigate and press `a` to add Jobs under Components
6. Press `<CR>` on any node to edit its details

### Planning Work

1. Open tree: `:Samplanner project-name`
2. Structure your work: Add Areas for major domains
3. Break down Areas: Add Components for functional units
4. Create Jobs: Add specific work items
5. Edit details: Press `<CR>` to flesh out each node
6. Estimate Jobs: Fill in estimation data for planning

### Tracking Time

1. Start work: `:SamplannerStart`
2. Timer appears in status line
3. Do work
4. Stop: `:SamplannerStop`
5. Edit session: `:SamplannerSession` to add notes and link tasks
6. Review time: Check time_log for historical data

### Finding Work

- **Search by text**: `:SamplannerSearch login` - Find tasks mentioning "login"
- **Filter by tag**: `:SamplannerByTag frontend` - Show all frontend tasks
- **Tree filters**: `tc` to hide completed, `ti` to show all

### Managing the Tree

- `a` - Add child node
- `A` - Add sibling node
- `d` - Delete node
- `r` - Rename node
- `J/K` - Move node down/up
- `>/<` - Increase/decrease indent (change parent)
- `o` - Toggle node expansion
- `<CR>` - Edit task details
- `<C-s>` - Save changes

## Key Benefits

1. **Structured Thinking**: The three-tier hierarchy with type-specific
   details forces you to think through work at the right level of
   abstraction

2. **Flexibility**: Tags and search allow multiple views beyond the hierarchy

3. **Time Awareness**: Integrated time tracking connects planning to reality

4. **Vim-Native**: Works within your editor, uses familiar keybindings

5. **Transparent**: Plain text JSON storage, no black box database

6. **Portable**: Files can be synced, versioned, backed up easily

7. **Estimation Tracking**: Compare estimates to actuals, improve over time

## Philosophy

Samplanner is designed around these principles:

- **Hierarchy for Structure**: Natural organization reflects how work breaks down
- **Details for Clarity**: Structured prompts ensure thorough planning
- **Time for Reality**: Track actual effort to calibrate future estimates
- **Text for Control**: Human-readable formats you can edit anywhere
- **Simplicity for Speed**: Fast operations, no complex UI, just your editor

The goal is to make planning a natural part of your workflow, not
a separate tool you have to context-switch to.
