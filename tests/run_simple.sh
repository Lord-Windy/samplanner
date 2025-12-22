#!/usr/bin/env bash
# Simple test runner without full busted dependencies
# This uses a minimal busted-compatible test runner

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEPS_DIR="$SCRIPT_DIR/deps"

# Check if dependencies are installed, if not run setup
if [ ! -d "$DEPS_DIR/dkjson" ]; then
  echo "Test dependencies not found. Running setup..."
  "$SCRIPT_DIR/setup_simple.sh"
  echo ""
fi

# Set up Lua paths
export LUA_PATH="$PROJECT_ROOT/lua/?.lua;$PROJECT_ROOT/lua/?/init.lua;;"

cd "$PROJECT_ROOT"

echo "Running tests with basic Lua test framework..."
echo ""

# Run unit tests
for test_file in tests/unit/*_spec.lua; do
  if [ -f "$test_file" ]; then
    echo "Running $(basename $test_file)..."
    luajit "$test_file"
    echo "✓ Passed"
    echo ""
  fi
done

# Run integration tests
for test_file in tests/integration/*_spec.lua; do
  if [ -f "$test_file" ]; then
    echo "Running $(basename $test_file)..."
    luajit "$test_file"
    echo "✓ Passed"
    echo ""
  fi
done

echo "All tests passed!"
