#!/bin/bash
# SubagentStop hook - updates task counter when swarm teammate completes
# Silent operation (no output to Claude)

set -euo pipefail

# shellcheck source=scripts/hook-helpers.sh
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"

STATE_FILE="$(get_state_file 2>/dev/null)" || exit 0
[[ ! -f "$STATE_FILE" ]] && exit 0

# Increment current_task (teammate completed one task)
CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
NEXT=$((CURRENT + 1))
frontmatter_set "$STATE_FILE" "current_task" "$NEXT"

# Silent success
exit 0
