#!/bin/bash
# SubagentStop hook - blocks if no commit was made during task execution
# Ensures task subagents commit their work before stopping
# Exempts read-only agents (code-reviewer, code-explorer, code-architect) during review/finish phases

set -euo pipefail

# Source frontmatter helpers
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"

# Fast exit if no state file (not in a workflow)
STATE_FILE="$(get_state_file)"
if [[ ! -f "$STATE_FILE" ]]; then
  echo '{"decision": "approve"}'
  exit 0
fi

# Check workflow phase: if all tasks complete, we're in review/finish phase
# Read-only agents (code-reviewer, code-explorer) run during this phase
CURRENT_TASK=$(frontmatter_get "$STATE_FILE" "current_task" "0")
TOTAL_TASKS=$(frontmatter_get "$STATE_FILE" "total_tasks" "0")

if [[ "$CURRENT_TASK" -ge "$TOTAL_TASKS" ]] && [[ "$TOTAL_TASKS" -gt 0 ]]; then
  # All tasks complete - approve (read-only agents don't need to commit)
  echo '{"decision": "approve"}'
  exit 0
fi

# Extract last known commit from state using safe helper
LAST_COMMIT=$(frontmatter_get "$STATE_FILE" "last_commit" "")
CURRENT_HEAD=$(git rev-parse HEAD 2>/dev/null || true)

# Deny if we can't determine commits (fail-safe: better to deny than approve)
if [[ -z "$LAST_COMMIT" ]]; then
  echo '{"decision": "deny", "reason": "Cannot verify commit - missing last_commit in state"}'
  exit 2
fi
if [[ -z "$CURRENT_HEAD" ]]; then
  echo '{"decision": "deny", "reason": "Cannot verify commit - git rev-parse failed"}'
  exit 2
fi

# Deny if no new commit was made
if [[ "$LAST_COMMIT" == "$CURRENT_HEAD" ]]; then
  echo '{"decision": "deny", "reason": "No commit detected. Run tests and commit before stopping."}'
  exit 2
fi

# New commit exists - approve
echo '{"decision": "approve"}'
