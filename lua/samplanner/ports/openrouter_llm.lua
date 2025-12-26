-- OpenRouter LLM implementation for Samplanner
-- Uses OpenAI-compatible API format
local llm = require('samplanner.ports.llm')
local models = require('samplanner.domain.models')

local M = {}

-- Configuration (set via samplanner.setup)
M.config = {
  endpoint = "https://openrouter.ai/api/v1/chat/completions",
  api_key = "",
  model = "anthropic/claude-sonnet-4-20250514",
  max_tokens = 1024,
}

-- Configure the provider
-- @param opts: table - { endpoint, api_key, model, max_tokens }
function M.configure(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

-- Check if provider is ready
-- @return boolean, string - ready status and message
function M.is_ready()
  if M.config.api_key == "" then
    return false, "OpenRouter API key not configured"
  end
  return true, "OpenRouter provider ready"
end

-- Make HTTP request to OpenRouter API using curl
-- @param messages: table - Array of message objects (OpenAI format)
-- @param callback: function(response, error)
local function make_request(messages, callback)
  local ready, err = M.is_ready()
  if not ready then
    callback(nil, err)
    return
  end

  local request_body = vim.fn.json_encode({
    model = M.config.model,
    max_tokens = M.config.max_tokens,
    messages = messages,
  })

  -- Escape the request body for shell
  local escaped_body = request_body:gsub("'", "'\\''")

  local cmd = string.format(
    [[curl -s -X POST "%s" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer %s" \
      -d '%s']],
    M.config.endpoint,
    M.config.api_key,
    escaped_body
  )

  -- Run asynchronously
  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data and data[1] and data[1] ~= "" then
        local response_text = table.concat(data, "\n")
        local ok, response = pcall(vim.fn.json_decode, response_text)
        if ok and response then
          if response.error then
            callback(nil, response.error.message or "API error")
          elseif response.choices and response.choices[1] and response.choices[1].message then
            callback(response.choices[1].message.content, nil)
          else
            callback(nil, "Unexpected response format")
          end
        else
          callback(nil, "Failed to parse API response")
        end
      end
    end,
    on_stderr = function(_, data)
      if data and data[1] and data[1] ~= "" then
        vim.schedule(function()
          vim.notify("OpenRouter API stderr: " .. table.concat(data, "\n"), vim.log.levels.DEBUG)
        end)
      end
    end,
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        callback(nil, "curl request failed with exit code: " .. exit_code)
      end
    end,
  })
end

-- Parse ambiguous user text into structured data
-- @param text: string - User input text to parse
-- @param target_type: string - Target type: "task", "session", or "structure"
-- @param context: table|nil - Optional context
-- @param callback: function - Callback function(result, error)
function M.parse_text(text, target_type, context, callback)
  context = context or {}

  local system_content = [[You are a task parsing assistant for a project planning tool.
Parse the user's natural language input into structured data.
Respond ONLY with valid JSON, no explanation or markdown.]]

  local user_prompt
  if target_type == "task" then
    user_prompt = string.format([[Parse this text into a task with the following JSON structure:
{
  "name": "short task name",
  "details": "detailed description",
  "estimation": "time estimate or empty string",
  "tags": ["array", "of", "tags"]
}

Existing project tags for reference: %s

User input:
%s]],
      vim.fn.json_encode(context.existing_tags or {}),
      text
    )
  elseif target_type == "session" then
    user_prompt = string.format([[Parse this text into session notes with the following JSON structure:
{
  "notes": "session notes",
  "interruptions": "interruption notes",
  "interruption_minutes": 0,
  "tasks": ["task_ids"]
}

Available task IDs: %s

User input:
%s]],
      vim.fn.json_encode(context.task_ids or {}),
      text
    )
  elseif target_type == "structure" then
    user_prompt = string.format([[Parse this text into a project structure with the following JSON structure:
{
  "nodes": [
    {"id": "1", "type": "Area", "name": "Area Name", "parent": null},
    {"id": "1.1", "type": "Component", "name": "Component Name", "parent": "1"},
    {"id": "1.1.1", "type": "Job", "name": "Job Name", "parent": "1.1"}
  ]
}

Types are: Area (top level), Component (middle), Job (leaf tasks).

User input:
%s]],
      text
    )
  else
    callback(nil, "Unknown target type: " .. target_type)
    return
  end

  -- OpenAI format: system message is a regular message with role "system"
  local messages = {
    { role = "system", content = system_content },
    { role = "user", content = user_prompt },
  }

  make_request(messages, function(response, err)
    if err then
      vim.schedule(function()
        callback(nil, err)
      end)
      return
    end

    -- Parse JSON response
    local ok, parsed = pcall(vim.fn.json_decode, response)
    if not ok then
      vim.schedule(function()
        callback(nil, "Failed to parse LLM response as JSON")
      end)
      return
    end

    -- Convert to appropriate model
    vim.schedule(function()
      if target_type == "task" then
        local task = models.Task.new(
          context.id or "",
          parsed.name or "",
          parsed.details or "",
          parsed.estimation or "",
          parsed.tags or {}
        )
        callback(task, nil)
      elseif target_type == "session" then
        local session = models.TimeLog.new(
          context.start_timestamp or "",
          context.end_timestamp or "",
          parsed.notes or "",
          parsed.interruptions or "",
          parsed.interruption_minutes or 0,
          parsed.tasks or {}
        )
        callback(session, nil)
      elseif target_type == "structure" then
        callback(parsed, nil)
      else
        callback(parsed, nil)
      end
    end)
  end)
end

-- Suggest tags for a task based on its content
-- @param task: Task - The task to suggest tags for
-- @param existing_tags: table - Array of existing project tags
-- @param callback: function - Callback function(tags, error)
function M.suggest_tags(task, existing_tags, callback)
  existing_tags = existing_tags or {}

  local system_content = [[You are a task tagging assistant.
Suggest relevant tags for the given task.
Prefer using existing tags when they fit.
Respond ONLY with a JSON array of tag strings, no explanation.]]

  local user_prompt = string.format([[Suggest tags for this task:

Name: %s
Details: %s

Existing project tags (prefer these when relevant): %s

Respond with a JSON array of 1-5 suggested tags.]],
    task.name or "",
    task.details or "",
    vim.fn.json_encode(existing_tags)
  )

  local messages = {
    { role = "system", content = system_content },
    { role = "user", content = user_prompt },
  }

  make_request(messages, function(response, err)
    if err then
      vim.schedule(function()
        callback(nil, err)
      end)
      return
    end

    -- Parse JSON response
    local ok, tags = pcall(vim.fn.json_decode, response)
    if not ok or type(tags) ~= "table" then
      vim.schedule(function()
        callback(nil, "Failed to parse LLM response as tag array")
      end)
      return
    end

    vim.schedule(function()
      callback(tags, nil)
    end)
  end)
end

-- Register this provider
llm.register_provider("openrouter", M)

return M
