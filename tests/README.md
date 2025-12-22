# Testing samplanner

This directory contains unit and integration tests for the samplanner Neovim plugin.

## Test Structure

- `unit/` - Unit tests for individual modules (models, utilities, etc.)
- `integration/` - Integration tests that test multiple components together
- `helpers/` - Helper utilities for testing

## Prerequisites

You just need:

- `luajit` or `lua` - Already installed with Neovim
- `git` - For downloading test JSON library (dkjson)

## Running Tests

### Simple runner (recommended)

The simplest way to run tests:

```bash
./tests/run_simple.sh
```

This runs all unit and integration tests using a minimal built-in test framework.

**Note:** The first time you run this, it will automatically download the required dependencies (dkjson) into `tests/deps/`.

### Run individual test files

```bash
luajit tests/unit/models_spec.lua
luajit tests/integration/file_storage_spec.lua
```

### Full busted setup (optional)

If you want to use the full busted test framework with all features:

```bash
./tests/setup.sh  # Download busted and dependencies
./tests/run.sh    # Run tests with busted
```

Note: The full busted setup requires compiling some C libraries and may have dependency issues.

### Cleanup

To remove all downloaded test dependencies and temporary files:

```bash
./tests/cleanup.sh
```

This removes:
- `tests/deps/` - All downloaded test dependencies (busted, dkjson, etc.)
- `tests/tmp/` - Temporary test files

## Writing Tests

Tests use the busted BDD-style syntax:

```lua
describe("ComponentName", function()
  it("should do something", function()
    local result = some_function()
    assert.are.equal(expected, result)
  end)
end)
```

### Common assertions

- `assert.are.equal(expected, actual)` - Check equality
- `assert.are.same(expected, actual)` - Deep equality for tables
- `assert.is_true(value)` - Check if true
- `assert.is_false(value)` - Check if false
- `assert.is_nil(value)` - Check if nil
- `assert.is_not_nil(value)` - Check if not nil

### Setup and teardown

```lua
describe("Test suite", function()
  before_each(function()
    -- Runs before each test
  end)
  
  after_each(function()
    -- Runs after each test
  end)
end)
```

## Notes

- Tests don't ship with the plugin distribution
- Integration tests mock `vim` global for testing outside Neovim
- Tests use LuaJIT for compatibility with Neovim
- The `.busted` config file in the root configures test behavior
