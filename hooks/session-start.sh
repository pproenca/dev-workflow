#!/bin/bash
# Session start hook - handles minimal state format
# No external dependencies (yq, jq) required

set -euo pipefail

# Source frontmatter helpers
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"

# Priority 1: Check for pending handoff
HANDOFF_FILE="$(get_handoff_file)"
if [[ -f "$HANDOFF_FILE" ]]; then
  # Extract from frontmatter using safe helpers
  MODE=$(frontmatter_get "$HANDOFF_FILE" "mode" "sequential")
  PLAN=$(frontmatter_get "$HANDOFF_FILE" "plan" "")

  if [[ "$MODE" == "subagent" ]]; then
    RESUME_CMD="Skill(\"dev-workflow:subagent-driven-development\")"
  else
    RESUME_CMD="/dev-workflow:execute-plan $PLAN"
  fi

  cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "<system-context>\\n**Pending workflow handoff detected.**\\n\\nPlan: $PLAN\\nMode: $MODE\\n\\nTo continue: $RESUME_CMD\\n</system-context>"
  }
}
EOF
  exit 0
fi

# Priority 2: Check for active workflow
STATE_FILE="$(get_state_file)"
if [[ -f "$STATE_FILE" ]]; then
  # Extract from frontmatter using safe helpers
  WORKFLOW=$(frontmatter_get "$STATE_FILE" "workflow" "unknown")
  PLAN=$(frontmatter_get "$STATE_FILE" "plan" "")
  CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
  TOTAL=$(frontmatter_get "$STATE_FILE" "total_tasks" "0")

  if [[ "$WORKFLOW" == "subagent" ]]; then
    RESUME_CMD="Skill(\"dev-workflow:subagent-driven-development\")"
  else
    RESUME_CMD="/dev-workflow:execute-plan $PLAN"
  fi

  cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "<system-context>\\n**Active workflow: $WORKFLOW**\\n\\nProgress: Task $CURRENT/$TOTAL\\nPlan: $PLAN\\n\\nTo resume: $RESUME_CMD\\n\\nTo abort: rm $STATE_FILE\\n</system-context>"
  }
}
EOF
  exit 0
fi

# Priority 3: Load getting-started skill
SKILL_FILE="${CLAUDE_PLUGIN_ROOT}/skills/getting-started/SKILL.md"

if [[ -f "$SKILL_FILE" ]]; then
  # Check file size (guard against large files)
  FILESIZE=$(wc -c < "$SKILL_FILE" | tr -d '[:space:]')
  if [[ "$FILESIZE" -gt 1048576 ]]; then
    echo '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "dev-workflow plugin active."}}'
    exit 0
  fi

  # Read and escape content for JSON
  CONTENT=$(cat "$SKILL_FILE" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

  cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "<system-context>\\ndev-workflow skills available.\\n\\n**Getting Started:**\\n\\n${CONTENT}\\n</system-context>"
  }
}
EOF
else
  echo '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "dev-workflow plugin active. Commands: /dev-workflow:write-plan, /dev-workflow:execute-plan"}}'
fi

exit 0
