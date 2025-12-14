---
description: Execute implementation plan with progress tracking and post-completion actions
argument-hint: [plan-file]
allowed-tools: Read, Write, Bash, TodoWrite, Task, Skill, AskUserQuestion
---

# Execute Plan

Execute implementation plan with state tracking and mandatory post-completion actions.

## Input

$ARGUMENTS

**If empty or file not found:** Stop with error "Plan file not found or not specified"

## Step 1: Initialize State

Read plan and create state file for resume capability:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
PLAN_FILE="$ARGUMENTS"

# Verify plan exists
if [[ ! -f "$PLAN_FILE" ]]; then
  echo "ERROR: Plan file not found: $PLAN_FILE"
  exit 1
fi

# Create state file
create_state_file "$PLAN_FILE"

# Read state
STATE_FILE="$(get_state_file)"
TOTAL=$(frontmatter_get "$STATE_FILE" "total_tasks" "0")
echo "STATE_FILE: $STATE_FILE"
echo "TOTAL_TASKS: $TOTAL"
```

**If TOTAL is 0:** Stop with error "No tasks found in plan. Tasks must use format: ### Task N: [Name]"

## Step 2: Setup TodoWrite

Extract task titles and create TodoWrite items:

```bash
grep -E "^### Task [0-9]+:" "$PLAN_FILE" | sed 's/^### Task \([0-9]*\): \(.*\)/Task \1: \2/'
```

Create TodoWrite with:
- All tasks from plan as `pending`
- "Code Review" as `pending`
- "Finish Branch" as `pending`

## Step 3: Choose Execution Mode

```claude
AskUserQuestion:
  header: "Mode"
  question: "How should tasks be executed?"
  multiSelect: false
  options:
    - label: "Sequential"
      description: "Execute tasks one by one with full TDD cycle"
    - label: "Parallel (Recommended)"
      description: "Run independent tasks concurrently via background agents"
```

---

## Sequential Execution

For each task in order:

### 3a. Read and Execute Task

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
STATE_FILE="$(get_state_file)"
CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
NEXT=$((CURRENT + 1))
echo "EXECUTING: Task $NEXT"
```

Mark task `in_progress` in TodoWrite.

Extract task section from plan. Use `Skill("dev-workflow:test-driven-development")` to implement.

### 3b. Update State After Each Task

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
STATE_FILE="$(get_state_file)"
CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
frontmatter_set "$STATE_FILE" "current_task" "$((CURRENT + 1))"
```

Mark task `completed` in TodoWrite. Continue to next task.

---

## Parallel Execution (Native Swarm)

Leverages Claude Code's native swarm by entering plan mode with our plan content.

### 3a. Analyze Plan for Swarm

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
PLAN_FILE="$ARGUMENTS"
TOTAL=$(frontmatter_get "$(get_state_file)" "total_tasks" "0")

# Analyze parallel groups to determine teammateCount
GROUPS=$(group_tasks_by_dependency "$PLAN_FILE" "$TOTAL" 5)
GROUP_COUNT=$(echo "$GROUPS" | tr '|' '\n' | wc -l | tr -d ' ')

echo "PARALLEL_GROUPS: $GROUPS"
echo "GROUP_COUNT: $GROUP_COUNT"

# Calculate teammateCount (max parallelism from groups)
# 1-2 groups: 2 teammates | 3-4 groups: 3-4 | 5+: 5 max
```

### 3b. Enter Plan Mode

Use `EnterPlanMode` to transition into native plan mode:

```claude
EnterPlanMode
```

### 3c. Write Our Plan to Native Plan File

Once in plan mode, read our persisted plan and write to the native plan file:

```bash
# Read our plan from docs/plans/
PLAN_CONTENT=$(cat "$PLAN_FILE")
echo "$PLAN_CONTENT"
```

Write this content to the native plan file (the system provides the path during plan mode).

**Important:** The plan is already in the correct task format (`### Task N: [Name]`) from `/dev-workflow:write-plan`.

### 3d. Exit with Native Swarm

```claude
ExitPlanMode:
  launchSwarm: true
  teammateCount: [GROUP_COUNT, max 5]
```

The native swarm:
- Reads our plan from the plan file
- Spawns teammates to execute tasks in parallel
- Each teammate follows the TDD instructions embedded in tasks
- `SubagentStop` hook fires for each completion → updates state file

### 3e. After Swarm Completes

The swarm executes autonomously. When all teammates finish:
- State file reflects completed task count (via SubagentStop hook)
- Proceed to Post-Completion Actions

---

## Step 4: Post-Completion Actions (MANDATORY)

After ALL tasks complete:

### 4a. Code Review

Mark "Code Review" `in_progress` in TodoWrite.

```claude
Task:
  subagent_type: dev-workflow:code-reviewer
  description: "Review all changes"
  prompt: |
    Review all changes from plan execution.
    Run: git diff main..HEAD
    Focus on cross-cutting concerns and consistency.
```

Use `Skill("dev-workflow:receiving-code-review")` to process feedback.

Mark "Code Review" `completed`.

### 4b. Finish Branch

Mark "Finish Branch" `in_progress` in TodoWrite.

Use `Skill("dev-workflow:finishing-a-development-branch")`.

Mark "Finish Branch" `completed`.

### 4c. Cleanup State

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
delete_state_file
echo "Workflow complete. State file deleted."
```

---

## Blocker Handling

If a task fails:

```claude
AskUserQuestion:
  header: "Blocker"
  question: "Task N failed. What to do?"
  multiSelect: false
  options:
    - label: "Skip"
      description: "Continue to next task"
    - label: "Retry"
      description: "Re-run the failed task"
    - label: "Stop"
      description: "Pause workflow, resume later with /dev-workflow:resume"
```

---

## Resume Capability

If session ends unexpectedly, next session detects state file:

```
ACTIVE WORKFLOW DETECTED
Plan: docs/plans/...
Progress: 3/8 tasks

Commands:
- /dev-workflow:resume - Continue execution
- /dev-workflow:abandon - Discard workflow state
```
