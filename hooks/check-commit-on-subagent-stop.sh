#!/bin/bash
# SubagentStop hook - blocks if no commit was made during task
# Ensures subagents commit their work before stopping

set -euo pipefail

# Source frontmatter helpers
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"

# Fast exit if no state file (not in a workflow)
STATE_FILE="$(get_state_file)"
if [[ ! -f "$STATE_FILE" ]]; then
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
