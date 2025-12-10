#!/bin/bash
# Stop hook - warns if workflow is active
# No external dependencies required

set -euo pipefail

# Source frontmatter helpers
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"

# Fast exit if no state file
STATE_FILE="$(get_state_file)"
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# Extract progress using safe helpers
CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
TOTAL=$(frontmatter_get "$STATE_FILE" "total_tasks" "0")

cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "Stop",
    "additionalContext": "**WORKFLOW ACTIVE**\\n\\nProgress: Task $CURRENT/$TOTAL\\n\\nStopping now preserves state. Resume with /dev-workflow:execute-plan or Skill(\"dev-workflow:subagent-driven-development\")"
  }
}
EOF

exit 0
