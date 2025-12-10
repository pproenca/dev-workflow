#!/usr/bin/env bash
# Dependency checker for dev-workflow plugin
# yq/jq no longer required for core functionality

set -euo pipefail

MISSING=()
OPTIONAL_MISSING=()

# Core requirements (only git now)
command -v git &> /dev/null || MISSING+=("git")

# Performance tools (recommended but optional)
command -v rg &> /dev/null || OPTIONAL_MISSING+=("rg (ripgrep) - faster grep")
command -v fd &> /dev/null || OPTIONAL_MISSING+=("fd (fd-find) - faster find")

# Optional tools are checked directly in the report below

# Report
echo "=== dev-workflow Dependencies ==="
echo ""

echo "Required:"
if command -v git &> /dev/null; then
  echo "  ✓ git"
else
  echo "  ✗ git (MISSING - required)"
fi

echo ""
echo "Optional (recommended):"
command -v rg &> /dev/null && echo "  ✓ rg (ripgrep)" || echo "  - rg (ripgrep) - faster searches"
command -v fd &> /dev/null && echo "  ✓ fd (fd-find)" || echo "  - fd (fd-find) - faster file finding"
command -v gh &> /dev/null && echo "  ✓ gh (GitHub CLI)" || echo "  - gh (GitHub CLI) - PR creation"

echo ""
echo "No longer required:"
echo "  - yq (YAML processor) - state now uses .local.md"
echo "  - jq (JSON processor) - hooks simplified"

echo ""

if [ ${#MISSING[@]} -eq 0 ]; then
  echo "Status: OK - all required dependencies present"
  exit 0
else
  echo "Status: MISSING required dependencies: ${MISSING[*]}"
  exit 1
fi
