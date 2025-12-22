#!/usr/bin/env bash
# Script to run tests with locally installed busted

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEPS_DIR="$SCRIPT_DIR/deps"

# Check if dependencies are installed
if [ ! -d "$DEPS_DIR/busted" ]; then
  echo "Test dependencies not found. Running setup..."
  "$SCRIPT_DIR/setup.sh"
fi

# Set up Lua paths
export LUA_PATH="$DEPS_DIR/busted/busted/?.lua;$DEPS_DIR/busted/?.lua;$DEPS_DIR/say/src/?.lua;$DEPS_DIR/luassert/src/?.lua;$DEPS_DIR/mediator_lua/src/?.lua;$DEPS_DIR/penlight/lua/?.lua;$DEPS_DIR/lua-term/?.lua;$DEPS_DIR/luasystem/?.lua;$DEPS_DIR/luasystem/?/init.lua;$PROJECT_ROOT/lua/?.lua;$PROJECT_ROOT/lua/?/init.lua;;"
export LUA_CPATH="$DEPS_DIR/luafilesystem/src/?.so;$DEPS_DIR/luasystem/src/core.so;;"

# Run busted with luajit
cd "$PROJECT_ROOT"

if command -v luajit &> /dev/null; then
  echo "Running tests with LuaJIT..."
  luajit "$DEPS_DIR/busted/bin/busted" "$@"
elif command -v lua &> /dev/null; then
  echo "Running tests with Lua..."
  lua "$DEPS_DIR/busted/bin/busted" "$@"
else
  echo "Error: Neither luajit nor lua found in PATH"
  exit 1
fi
