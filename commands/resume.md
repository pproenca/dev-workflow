---
description: Resume interrupted plan execution
allowed-tools: Read, Bash, TodoWrite, Task, Skill, AskUserQuestion
---

# Resume Workflow

Resume execution of an interrupted plan from where it left off.

## Step 1: Read State

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
STATE_FILE="$(get_state_file)"
PLAN=$(frontmatter_get "$STATE_FILE" "plan" "")
CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
TOTAL=$(frontmatter_get "$STATE_FILE" "total_tasks" "0")
BASE_SHA=$(frontmatter_get "$STATE_FILE" "base_sha" "")
echo "PLAN:$PLAN"
echo "CURRENT:$CURRENT"
echo "TOTAL:$TOTAL"
echo "BASE_SHA:$BASE_SHA"
```

## Step 2: Verify State

1. Read the plan file at `$PLAN`
2. Check git log since `$BASE_SHA` to see completed work:
   ```bash
   git log --oneline $BASE_SHA..HEAD
   ```
3. Count completed tasks (should match `$CURRENT`)

## Step 3: Ask User

Use AskUserQuestion:

```claude
AskUserQuestion:
  header: "Resume"
  question: "Continue from task [CURRENT+1] of [TOTAL]?"
  multiSelect: false
  options:
    - label: "Continue"
      description: "Resume sequential execution from where we left off"
    - label: "Review first"
      description: "Show completed work before continuing"
```

## Step 4: Execute

**If Continue:**
1. Create TodoWrite with remaining tasks (from plan file, tasks CURRENT+1 to TOTAL)
2. Follow "Executing Existing Plans" from getting-started skill
3. Start from task `$((CURRENT + 1))`

**If Review first:**
1. Show git log since base_sha with diff summary
2. Show which tasks are marked complete
3. Then ask again if ready to continue

## Step 5: Complete Workflow

After all tasks done:
1. Run code review (Task tool with dev-workflow:code-reviewer)
2. Use Skill("dev-workflow:receiving-code-review")
3. Use Skill("dev-workflow:finishing-a-development-branch")
4. Delete state file:
   ```bash
   source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
   delete_state_file
   ```
