#!/bin/bash
# SubagentStop hook - fires when a background agent completes
#
# NOTE: State updates are handled by the orchestrator (execute-plan.md)
# after waiting for TaskOutput. This hook does NOT modify state to avoid
# race conditions between SubagentStop and orchestrator updates.
#
# This hook can be used for logging or other side effects if needed.

set -euo pipefail

# Silent success - orchestrator handles state
exit 0
