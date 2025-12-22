#!/usr/bin/env bash
# Setup script for downloading test dependencies

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPS_DIR="$SCRIPT_DIR/deps"

echo "Setting up test dependencies in $DEPS_DIR..."

# Create deps directory
mkdir -p "$DEPS_DIR"
cd "$DEPS_DIR"

# Download busted and its dependencies
echo "Downloading busted..."
if [ ! -d "busted" ]; then
  git clone --depth=1 https://github.com/lunarmodules/busted.git
fi

echo "Downloading lua-term (busted dependency)..."
if [ ! -d "lua-term" ]; then
  git clone --depth=1 https://github.com/hoelzro/lua-term.git
fi

echo "Downloading say (busted dependency)..."
if [ ! -d "say" ]; then
  git clone --depth=1 https://github.com/lunarmodules/say.git
fi

echo "Downloading luassert (busted dependency)..."
if [ ! -d "luassert" ]; then
  git clone --depth=1 https://github.com/lunarmodules/luassert.git
fi

echo "Downloading mediator_lua (busted dependency)..."
if [ ! -d "mediator_lua" ]; then
  git clone --depth=1 https://github.com/Olivine-Labs/mediator_lua.git
fi

echo "Downloading penlight (busted dependency)..."
if [ ! -d "penlight" ]; then
  git clone --depth=1 https://github.com/lunarmodules/Penlight.git penlight
fi

echo "Downloading dkjson (for JSON handling in tests)..."
if [ ! -d "dkjson" ]; then
  git clone --depth=1 https://github.com/LuaDist/dkjson.git
fi

echo "Downloading luasystem (busted dependency)..."
if [ ! -d "luasystem" ]; then
  git clone --depth=1 https://github.com/lunarmodules/luasystem.git
  cd luasystem
  if command -v luajit &> /dev/null; then
    # Find LuaJIT include directory
    LUA_INC=""
    for path in /usr/include/luajit-* /usr/local/include/luajit-* /usr/include; do
      if [ -f "$path/lua.h" ]; then
        LUA_INC="$path"
        break
      fi
    done
    
    if [ -n "$LUA_INC" ]; then
      echo "Building luasystem with LUA_INC=$LUA_INC"
      make MYCFLAGS="-I$LUA_INC"
    fi
  fi
  cd ..
fi

echo "Downloading luafilesystem (busted dependency)..."
if [ ! -d "luafilesystem" ]; then
  git clone --depth=1 https://github.com/lunarmodules/luafilesystem.git
  # Build luafilesystem
  cd luafilesystem
  if command -v luajit &> /dev/null; then
    # Find LuaJIT include directory
    LUA_INC=""
    for path in /usr/include/luajit-* /usr/local/include/luajit-* /usr/include; do
      if [ -f "$path/lua.h" ]; then
        LUA_INC="$path"
        break
      fi
    done
    
    if [ -n "$LUA_INC" ]; then
      echo "Building luafilesystem with LUA_INC=$LUA_INC"
      make LUA_INC="-I$LUA_INC"
    else
      echo "Error: Could not find Lua headers (lua.h)"
      echo "Please install luajit development files:"
      echo "  Gentoo: emerge -av dev-lang/luajit"
      exit 1
    fi
  else
    echo "Warning: LuaJIT not found. Skipping luafilesystem build."
  fi
  cd ..
fi

echo ""
echo "✓ Test dependencies installed successfully!"
echo ""
echo "To run tests, use: ./tests/run.sh"
