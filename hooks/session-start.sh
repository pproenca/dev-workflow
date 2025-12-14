#!/bin/bash
# Session start hook - loads getting-started skill with planning methodology
# No external dependencies required

set -euo pipefail

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
