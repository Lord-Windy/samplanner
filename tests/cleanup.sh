#!/usr/bin/env bash
# Cleanup script to remove all test dependencies and temporary files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPS_DIR="$SCRIPT_DIR/deps"
TMP_DIR="$SCRIPT_DIR/tmp"

echo "Cleaning up test dependencies and temporary files..."

# Remove dependencies directory
if [ -d "$DEPS_DIR" ]; then
  echo "Removing $DEPS_DIR..."
  rm -rf "$DEPS_DIR"
  echo "✓ Removed test dependencies"
else
  echo "ℹ No dependencies directory found"
fi

# Remove temporary test files
if [ -d "$TMP_DIR" ]; then
  echo "Removing $TMP_DIR..."
  rm -rf "$TMP_DIR"
  echo "✓ Removed temporary test files"
else
  echo "ℹ No temporary files found"
fi

echo ""
echo "✓ Cleanup complete!"
echo ""
echo "To reinstall test dependencies, run: ./tests/setup.sh"
