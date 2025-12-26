local M = {}

local defaults = {
  filepath = "/home/sam/Dropbox/planning",
  llm = {
    provider = "anthropic",  -- "anthropic" or "openrouter"
    endpoint = "",  -- auto-set based on provider if empty
    api_key = "",
    model = "",  -- auto-set based on provider if empty
    max_tokens = 1024,
  },
}

-- Provider-specific defaults
local provider_defaults = {
  anthropic = {
    endpoint = "https://api.anthropic.com/v1/messages",
    model = "claude-sonnet-4-20250514",
    env_key = "ANTHROPIC_API_KEY",
  },
  openrouter = {
    endpoint = "https://openrouter.ai/api/v1/chat/completions",
    model = "anthropic/claude-sonnet-4-20250514",
    env_key = "OPENROUTER_API_KEY",
  },
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", {}, defaults, opts or {})

  local provider = M.config.llm.provider
  local pdefaults = provider_defaults[provider]

  if pdefaults then
    -- Set endpoint from provider defaults if not specified
    if M.config.llm.endpoint == "" then
      M.config.llm.endpoint = pdefaults.endpoint
    end

    -- Set model from provider defaults if not specified
    if M.config.llm.model == "" then
      M.config.llm.model = pdefaults.model
    end

    -- Get API key from environment if not provided
    if M.config.llm.api_key == "" then
      M.config.llm.api_key = os.getenv(pdefaults.env_key) or ""
    end
  end

  -- Initialize LLM provider
  local llm = require('samplanner.ports.llm')

  if provider == "anthropic" then
    local anthropic = require('samplanner.ports.anthropic_llm')
    anthropic.configure(M.config.llm)
    llm.set_provider("anthropic")
  elseif provider == "openrouter" then
    local openrouter = require('samplanner.ports.openrouter_llm')
    openrouter.configure(M.config.llm)
    llm.set_provider("openrouter")
  end
end

return M
