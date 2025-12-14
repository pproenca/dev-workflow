#!/bin/bash
# Stop hook - warns about active workflow when session ends
# Provides resume instructions for next session

set -euo pipefail

# shellcheck source=scripts/hook-helpers.sh
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"

STATE_FILE="$(get_state_file 2>/dev/null)" || exit 0
[[ ! -f "$STATE_FILE" ]] && exit 0

# Active workflow exists - warn user
PLAN=$(frontmatter_get "$STATE_FILE" "plan" "")
CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
TOTAL=$(frontmatter_get "$STATE_FILE" "total_tasks" "0")

cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "Stop",
    "additionalContext": "**WORKFLOW PAUSED**\\n\\nProgress: ${CURRENT}/${TOTAL} tasks\\nPlan: ${PLAN}\\n\\nResume in new session with: /dev-workflow:resume"
  }
}
EOF
