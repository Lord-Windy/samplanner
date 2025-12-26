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

Functions to convert BACK from the tasks should be done in a way with use
of AI for now. In future I may look at a treesitter like parser but for
now I think Haiku would be good. I've used it in the past. But it would
need to be API agnostic using the ports so I can pick and choose. In the
future I will likely want to use OpenRouter instead. Also the
implementation doesn't have to look like below. I've just used this in the
past. For example we wouldn't be using Markdown

``` 


local function generate_comment_processing_json(content)

  local payload = "Please read the markdown file below and fill in all sections marked with << >>. Replace each << >> section with appropriate content based on the context. Return the complete markdown file with all << >> sections filled in. Do not add any additional commentary, explanations, or text outside of the markdown file itself. \n\n" .. content

  local message_data = {
    model = M.config.model,
    thinking = {
      type = "enabled",
      budget_tokens = 4096
    },
    system =
    "You are a world class writer. You are my assistant and your job is to help me write documentation and prose were appropriate.",
    max_tokens = 16000,
    messages = {
      {
        role = "user",
        content = payload
      }
    }
  }

  return vim.json.encode(message_data)
end

function M.process(_)
  -- grab the entire contents of the current buffer
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local text = table.concat(lines, "\n")

  -- create backup of the original buffer when enabled
  if M.config.backup_original then
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local basename = vim.fn.fnamemodify(bufname, ":t")
    local day = os.date("%Y-%m-%d")
    local timestamp = os.date("%Y-%m-%dT%H-%M-%S")
    local dir = cache_root .. "/" .. day
    ensure_dir(dir)
    local outfile = string.format("%s/%s-%s.orig", dir, basename, timestamp)
    vim.fn.writefile(lines, outfile)
  end

  -- create payload for Anthropic Claude
  local payload = generate_comment_processing_json(text)

  -- send the payload using curl
  local cmd = {
    "curl",
    "-s",
    "-X",
    "POST",
    "-H",
    "Content-Type: application/json",
    "-H",
    "anthropic-version: 2023-06-01",
    "-H",
    "x-api-key: " .. M.config.api_key,
    "-d",
    payload,
    M.config.endpoint,
  }

  local result = vim.fn.system(cmd)
  append_log(result)

  local ok, decoded = pcall(vim.json.decode, result)
  if not ok then
    sam_llm_debug("Error decoding response: " .. decoded)
    return
  end

  local collected = {}
  if decoded and decoded.content and type(decoded.content) == "table" then
    for _, item in ipairs(decoded.content) do
      if item.type == "text" and item.text then
        table.insert(collected, item.text)
      end
    end
  end

  local new_text = table.concat(collected, "\n")
  local new_lines = vim.split(new_text, "\n")

  if M.config.backup_response then
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local basename = vim.fn.fnamemodify(bufname, ":t")
    local day = os.date("%Y-%m-%d")
    local timestamp = os.date("%Y-%m-%dT%H-%M-%S")
    local dir = cache_root .. "/" .. day
    ensure_dir(dir)
    local outfile = string.format("%s/%s-%s.response", dir, basename, timestamp)
    vim.fn.writefile(new_lines, outfile)
  end

  -- replace the buffer with the new content
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
end

```


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



