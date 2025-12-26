-- Abstract LLM interface for Samplanner
-- This module defines the interface that LLM implementations must follow

local M = {}

-- Registry of LLM providers
M.providers = {}

-- Current active provider
M.current_provider = nil

-- Register an LLM provider
-- @param name: string - Provider name (e.g., "anthropic", "openrouter")
-- @param provider: table - Provider implementation with required methods
function M.register_provider(name, provider)
  M.providers[name] = provider
end

-- Set the active provider
-- @param name: string - Provider name to activate
-- @return boolean, string - success status and error message if failed
function M.set_provider(name)
  local provider = M.providers[name]
  if not provider then
    return false, "Unknown LLM provider: " .. name
  end
  M.current_provider = provider
  return true, nil
end

-- Get the active provider
-- @return table|nil - The current provider or nil
function M.get_provider()
  return M.current_provider
end

--------------------------------------------------------------------------------
-- LLM Interface Methods
-- These methods delegate to the active provider
--------------------------------------------------------------------------------

-- Parse ambiguous user text into structured data
-- @param text: string - User input text to parse
-- @param target_type: string - Target type: "task", "session", or "structure"
-- @param context: table|nil - Optional context (existing tags, project info, etc.)
-- @param callback: function - Callback function(result, error)
function M.parse_text(text, target_type, context, callback)
  local provider = M.current_provider
  if not provider then
    callback(nil, "No LLM provider configured")
    return
  end

  if not provider.parse_text then
    callback(nil, "Provider does not support parse_text")
    return
  end

  provider.parse_text(text, target_type, context, callback)
end

-- Suggest tags for a task based on its content
-- @param task: Task - The task to suggest tags for
-- @param existing_tags: table - Array of existing project tags
-- @param callback: function - Callback function(tags, error)
function M.suggest_tags(task, existing_tags, callback)
  local provider = M.current_provider
  if not provider then
    callback(nil, "No LLM provider configured")
    return
  end

  if not provider.suggest_tags then
    callback(nil, "Provider does not support suggest_tags")
    return
  end

  provider.suggest_tags(task, existing_tags, callback)
end

-- Check if provider is configured and ready
-- @return boolean, string - ready status and message
function M.is_ready()
  local provider = M.current_provider
  if not provider then
    return false, "No LLM provider configured"
  end

  if provider.is_ready then
    return provider.is_ready()
  end

  return true, "Provider ready"
end

--------------------------------------------------------------------------------
-- Provider Interface Definition
-- Implementations must provide these methods:
--
-- provider.parse_text(text, target_type, context, callback)
--   Parse user text into structured format
--   - text: string - Raw user input
--   - target_type: "task" | "session" | "structure"
--   - context: table - { existing_tags, project_info, ... }
--   - callback: function(result, error)
--     - result: parsed model or nil on error
--     - error: string error message or nil on success
--
-- provider.suggest_tags(task, existing_tags, callback)
--   Suggest tags for a task
--   - task: Task model
--   - existing_tags: array of strings
--   - callback: function(tags, error)
--     - tags: array of suggested tag strings
--     - error: string error message or nil
--
-- provider.is_ready() -> boolean, string
--   Check if provider is configured (API key set, etc.)
--------------------------------------------------------------------------------

return M
