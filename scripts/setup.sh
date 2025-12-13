#!/usr/bin/env bash
# One-click contributor setup for dev-workflow plugin
# Usage: ./scripts/setup.sh

set -euo pipefail

SCRIPT_DIR="$(command cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(command cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Setting up dev-workflow for contributors ==="
echo ""

# Detect OS and package manager
if [[ "$OSTYPE" == "darwin"* ]]; then
  PKG_MGR="brew"
  if ! command -v brew &>/dev/null; then
    echo "Error: Homebrew required. Install from https://brew.sh"
    exit 1
  fi
elif command -v apt-get &>/dev/null; then
  PKG_MGR="apt"
else
  echo "Error: Unsupported OS. Install bats-core and pre-commit manually."
  exit 1
fi

# Install bats-core
if ! command -v bats &>/dev/null; then
  echo "Installing bats-core..."
  if [[ "$PKG_MGR" == "brew" ]]; then
    brew install bats-core
  else
    sudo apt-get update && sudo apt-get install -y bats
  fi
else
  echo "✓ bats-core already installed"
fi

# Install shellcheck
if ! command -v shellcheck &>/dev/null; then
  echo "Installing shellcheck..."
  if [[ "$PKG_MGR" == "brew" ]]; then
    brew install shellcheck
  else
    sudo apt-get update && sudo apt-get install -y shellcheck
  fi
else
  echo "✓ shellcheck already installed"
fi

# Install pre-commit
if ! command -v pre-commit &>/dev/null; then
  echo "Installing pre-commit..."
  if [[ "$PKG_MGR" == "brew" ]]; then
    brew install pre-commit
  else
    pip3 install pre-commit
  fi
else
  echo "✓ pre-commit already installed"
fi

# Setup git hooks
echo ""
echo "Setting up pre-commit hooks..."
command cd "$PLUGIN_ROOT"
pre-commit install

# Verify
echo ""
echo "Running validation..."
"$PLUGIN_ROOT/scripts/validate.sh"

echo ""
echo "=== Setup complete! ==="
echo ""
echo "Pre-commit hooks will run automatically on every commit."
echo ""
echo "Manual commands:"
echo "  bats tests/           # Run tests"
echo "  ./scripts/validate.sh # Run validation"
