#!/bin/bash
# Session start hook - detects active workflow or loads getting-started skill
# No external dependencies required

set -euo pipefail

# Try to source hook-helpers.sh if available (for state file detection)
HELPERS="${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
if [[ -f "$HELPERS" ]]; then
  # shellcheck source=scripts/hook-helpers.sh
  source "$HELPERS"

  # Check for active workflow FIRST (resume capability)
  STATE_FILE="$(get_state_file 2>/dev/null)" || STATE_FILE=""

  if [[ -n "$STATE_FILE" ]] && [[ -f "$STATE_FILE" ]]; then
    PLAN=$(frontmatter_get "$STATE_FILE" "plan" "")
    CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
    TOTAL=$(frontmatter_get "$STATE_FILE" "total_tasks" "0")

    # Output resume context instead of getting-started skill
    cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "<system-context>\\n**ACTIVE WORKFLOW DETECTED**\\n\\nPlan: ${PLAN}\\nProgress: ${CURRENT}/${TOTAL} tasks\\n\\nCommands:\\n- /dev-workflow:resume - Continue execution\\n- /dev-workflow:abandon - Discard workflow state\\n</system-context>"
  }
}
EOF
    exit 0
  fi
fi

# No active workflow - load getting-started skill
SKILL_FILE="${CLAUDE_PLUGIN_ROOT}/skills/getting-started/SKILL.md"

if [[ -f "$SKILL_FILE" ]]; then
  # Check file size (guard against large files)
  FILESIZE=$(wc -c < "$SKILL_FILE" | tr -d '[:space:]')
  if [[ "$FILESIZE" -gt 1048576 ]]; then
    echo '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "dev-workflow plugin active."}}'
    exit 0
  fi

  # Read and escape content for JSON (awk for BSD/GNU portability)
  CONTENT=$(sed 's/\\/\\\\/g' "$SKILL_FILE" | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')

  cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "<system-context>\\ndev-workflow skills available.\\n\\n**Getting Started:**\\n\\n${CONTENT}\\n</system-context>"
  }
}
EOF
else
  echo '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "dev-workflow plugin active. Use EnterPlanMode for planning, /dev-workflow:brainstorm for ideation."}}'
fi

exit 0
