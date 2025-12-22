-- Minimal test framework compatible with busted syntax
-- Just enough to run our tests without full busted dependencies

local M = {}

local current_suite = nil
local test_count = 0
local passed_count = 0
local failed_tests = {}

-- Assert library
local assert_lib = {
  are = {}
}

function assert_lib.are.equal(expected, actual)
  if expected ~= actual then
    error(string.format("Expected %s but got %s", tostring(expected), tostring(actual)), 2)
  end
end

function assert_lib.are.same(expected, actual)
  local function deep_equal(t1, t2)
    if type(t1) ~= type(t2) then return false end
    if type(t1) ~= "table" then return t1 == t2 end
    for k, v in pairs(t1) do
      if not deep_equal(v, t2[k]) then return false end
    end
    for k in pairs(t2) do
      if t1[k] == nil then return false end
    end
    return true
  end
  
  if not deep_equal(expected, actual) then
    error(string.format("Tables are not the same"), 2)
  end
end

function assert_lib.is_true(value)
  if value ~= true then
    error(string.format("Expected true but got %s", tostring(value)), 2)
  end
end

function assert_lib.is_false(value)
  if value ~= false then
    error(string.format("Expected false but got %s", tostring(value)), 2)
  end
end

function assert_lib.is_nil(value)
  if value ~= nil then
    error(string.format("Expected nil but got %s", tostring(value)), 2)
  end
end

function assert_lib.is_not_nil(value)
  if value == nil then
    error("Expected non-nil value", 2)
  end
end

assert_lib.are = assert_lib.are or {}
setmetatable(assert_lib, {
  __index = function(t, k)
    if k == "are" then
      rawset(t, "are", {equal = assert_lib.are.equal, same = assert_lib.are.same})
      return t.are
    end
  end
})

-- Global functions
local before_each_fn = nil
local after_each_fn = nil

function _G.describe(name, func)
  current_suite = name
  before_each_fn = nil
  after_each_fn = nil
  print(string.format("\n%s", name))
  func()
  current_suite = nil
  before_each_fn = nil
  after_each_fn = nil
end

function _G.it(description, func)
  test_count = test_count + 1
  
  -- Run before_each if defined
  if before_each_fn then
    pcall(before_each_fn)
  end
  
  local success, err = pcall(func)
  
  -- Run after_each if defined
  if after_each_fn then
    pcall(after_each_fn)
  end
  
  if success then
    passed_count = passed_count + 1
    print(string.format("  ✓ %s", description))
  else
    table.insert(failed_tests, {
      suite = current_suite,
      test = description,
      error = err
    })
    print(string.format("  ✗ %s", description))
    print(string.format("    %s", err))
  end
end

function _G.before_each(func)
  before_each_fn = func
end

function _G.after_each(func)
  after_each_fn = func
end

-- Set global assert
_G.assert = assert_lib

-- Export for explicit use
M.run_summary = function()
  print(string.format("\n\n%d tests, %d passed, %d failed", 
    test_count, passed_count, test_count - passed_count))
  
  if #failed_tests > 0 then
    print("\nFailed tests:")
    for _, fail in ipairs(failed_tests) do
      print(string.format("  %s - %s", fail.suite, fail.test))
    end
    os.exit(1)
  end
end

return M
