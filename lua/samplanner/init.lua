local M = {}

local defaults = {
  filepath = "/home/sam/Dropbox/planning"
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", {}, defaults, opts or {})
end


return M
