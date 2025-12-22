#!/usr/bin/env bash
# Minimal setup script for simple test runner
# Only downloads what's needed for tests/run_simple.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPS_DIR="$SCRIPT_DIR/deps"

echo "Setting up minimal test dependencies in $DEPS_DIR..."

# Create deps directory
mkdir -p "$DEPS_DIR"
cd "$DEPS_DIR"

# Download dkjson for JSON handling in tests
echo "Downloading dkjson (for JSON handling in tests)..."
if [ ! -d "dkjson" ]; then
  git clone --depth=1 https://github.com/LuaDist/dkjson.git
fi

echo ""
echo "✓ Test dependencies installed successfully!"
echo ""
echo "To run tests, use: ./tests/run_simple.sh"
