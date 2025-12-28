This is funny because I need the software built before i can do planning
how I would really like to do it. So I'm going to broad strokes this so
I can get to the using of the tool and improving it.

I have the structure built, so go me!

I need functions to:

- Create a project 
- Create the tree structure of tasks and add to it
- Function to present the tree structure of tasks
- Append tasks to the tree from any position and add the numbering
- Function to re-number all the tasks as needed so they make sense
- Create the detailed tasks
- Have the format of the tasks be similar to the time task format for easy
  viewing and editting
- Function to convert back and forward from that
- Create the a time task and stop it
- Functions to convert a time task to and from this format for editting


```
── Session ──────────────────────────
Start: 2024-01-15 09:00
End:   2024-01-15 10:30

── Notes ────────────────────────────
(your notes here)

── Interruptions (minutes: 15) ──────
(describe interruptions here)

── Tasks ────────────────────────────
- task_001
- task_002 

```

- Build out the tags to help with tagging
- Search/filter by tags

I then need to create Neovim plugin style functions that would allow me to
interface with the new functions

Interfaces needed:

- Create a buffer for the time tasks, can open old or new and save back on
  :w
- Treelike hireachy view - being able to add and remove tasks to the tree
  quickly and easily with the ability to give the tasks names but don't
  necessasirly need to work on the modal just yet
- Easy call up of a task for a modal OR extra buffer. Save on :w
- Add and remove tags from a list
- Add tags with fuzzy search to tasks easily
- Search by tag



