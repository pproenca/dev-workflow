---
description: Display current workflow state and progress
argument-hint:
allowed-tools: Bash, Read, AskUserQuestion
---

# Workflow Status

Check for active workflows and display progress.

## Path Resolution

!`STATE_FILE="$(git rev-parse --show-toplevel)/.claude/dev-workflow-state.local.md" && HANDOFF_FILE="$(git rev-parse --show-toplevel)/.claude/pending-handoff.local.md" && echo "STATE_FILE:$STATE_FILE"`

## Current State

!`echo "=== Dev-Workflow Status ===" && echo "" && (test -f "$STATE_FILE" && echo "ACTIVE WORKFLOW FOUND" && echo "" && cat "$STATE_FILE" || echo "No active workflow.") && echo "" && echo "=== Git Worktrees ===" && (source "${CLAUDE_PLUGIN_ROOT}/scripts/worktree-manager.sh" && list_worktrees 2>/dev/null || echo "Not a git repository")`

## Actions

### If Active Workflow Found

If state file exists, use AskUserQuestion:

```claude
AskUserQuestion:
  header: "Actions"
  question: "What would you like to do?"
  multiSelect: false
  options:
    - label: "Continue"
      description: "Resume the active workflow"
    - label: "Reset"
      description: "Clear state and start fresh"
    - label: "Nothing"
      description: "Just checking status"
```

**If Continue:**

Read workflow type and plan from state file:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
WORKFLOW="$(frontmatter_get "$STATE_FILE" "workflow" "")"
PLAN="$(frontmatter_get "$STATE_FILE" "plan" "")"
echo "WORKFLOW:$WORKFLOW PLAN:$PLAN"
```

- If `workflow: execute-plan`: `/dev-workflow:execute-plan [PLAN]`
- If `workflow: subagent`: `Skill("dev-workflow:subagent-driven-development")`

**If Reset:**

Confirm with AskUserQuestion:

```claude
AskUserQuestion:
  header: "Confirm"
  question: "Delete workflow state? This cannot be undone."
  multiSelect: false
  options:
    - label: "Yes, reset"
      description: "Delete all workflow state files permanently"
    - label: "Cancel"
      description: "Keep state and return to previous menu"
```

If confirmed:
```bash
rm -f "$STATE_FILE"
rm -f "$HANDOFF_FILE"
echo "Workflow state cleared."
```

**If Nothing:** End response.
