-- Storage interface for project persistence
-- This defines the contract that all storage implementations must follow

local M = {}

-- Interface definition (documentation only - Lua doesn't enforce interfaces)
-- All storage implementations should provide these functions:

-- Saves a project to storage
-- @param project: Project - The project model to save
-- @param directory: string - The directory path where the project should be saved
-- @return boolean, string - success status and error message if failed
function M.save(project, directory) -- luacheck: ignore
  error("save() must be implemented by storage implementation")
end

-- Loads a project from storage
-- @param project_name: string - The name of the project to load
-- @param directory: string - The directory path where the project is stored
-- @return Project, string - the loaded project or nil, and error message if failed
function M.load(project_name, directory) -- luacheck: ignore
  error("load() must be implemented by storage implementation")
end

-- Lists all available projects in a directory
-- @param directory: string - The directory path to search for projects
-- @return table - array of project names
function M.list_projects(directory) -- luacheck: ignore
  error("list_projects() must be implemented by storage implementation")
end

return M
