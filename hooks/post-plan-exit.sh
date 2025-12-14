#!/bin/bash
# PostPlanModeExit hook - reminds Claude of post-swarm actions
# Fires after ExitPlanMode completes
#
# Timing assumption: If ExitPlanMode(launchSwarm: true) was called,
# this hook fires AFTER the swarm completes, not before.
# The swarm is part of the ExitPlanMode operation.

set -euo pipefail

# Only provide context if a swarm was likely launched (plan file exists)
if [[ -n "${CLAUDE_PLAN_FILE:-}" ]] && [[ -f "${CLAUDE_PLAN_FILE}" ]]; then
  cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostPlanModeExit",
    "additionalContext": "**POST-PLAN EXECUTION**\n\nIf swarm was launched (ExitPlanMode with launchSwarm: true), you MUST now:\n\n1. **Code Review** - Dispatch code-reviewer agent:\n   Task(subagent_type: 'dev-workflow:code-reviewer', prompt: 'Review all changes. git diff main..HEAD')\n\n2. **Process Feedback** - Use Skill('dev-workflow:receiving-code-review')\n\n3. **Finish Branch** - Use Skill('dev-workflow:finishing-a-development-branch')\n\nThese steps ensure code quality. Do not skip them."
  }
}
EOF
else
  # No plan file, just exit cleanly
  exit 0
fi
