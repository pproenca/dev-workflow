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

## Parallel Execution (Background Agents)

Uses `Task(run_in_background)` + `TaskOutput` pattern from tools.md to execute tasks in parallel while respecting dependencies.

### 3a. Analyze Task Groups

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
PLAN_FILE="$ARGUMENTS"
STATE_FILE="$(get_state_file)"
TOTAL=$(frontmatter_get "$STATE_FILE" "total_tasks" "0")

# Group tasks by file dependencies
# Tasks in same group have NO file overlap → can run parallel
# Groups execute serially (group1 completes before group2 starts)
TASK_GROUPS=$(group_tasks_by_dependency "$PLAN_FILE" "$TOTAL" 5)
MAX_PARALLEL=$(get_max_parallel_from_groups "$TASK_GROUPS")

echo "TASK_GROUPS: $TASK_GROUPS"
echo "MAX_PARALLEL: $MAX_PARALLEL"
```

### 3b. Execute Groups Serially, Tasks in Parallel

For each group in `TASK_GROUPS` (split by `|`):

**If group has multiple tasks** (e.g., `group1:1,2,3`):

1. Launch ALL tasks in the group simultaneously using `Task(run_in_background: true)`:

```claude
# Launch in SINGLE message for true parallelism
Task:
  subagent_type: general-purpose
  description: "Execute Task 1"
  prompt: |
    Execute Task 1 from plan. Follow TDD instructions exactly.
    [Task 1 content extracted via get_task_content]
  run_in_background: true

Task:
  subagent_type: general-purpose
  description: "Execute Task 2"
  prompt: |
    Execute Task 2 from plan. Follow TDD instructions exactly.
    [Task 2 content extracted via get_task_content]
  run_in_background: true
```

2. Wait for ALL agents in the group to complete:

```claude
# Wait for all background agents
TaskOutput:
  task_id: [agent_id_1]
  block: true

TaskOutput:
  task_id: [agent_id_2]
  block: true
```

3. Update state after group completes:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
STATE_FILE="$(get_state_file)"
# Set to last task number in completed group
frontmatter_set "$STATE_FILE" "current_task" "[LAST_TASK_IN_GROUP]"
```

4. Mark completed tasks in TodoWrite.

**If group has single task** (e.g., `group3:5`):

Execute foreground (no background needed):

```claude
Task:
  subagent_type: general-purpose
  description: "Execute Task 5"
  prompt: |
    Execute Task 5 from plan. Follow TDD instructions exactly.
    [Task 5 content]
```

Update state and TodoWrite after completion.

### 3c. Why This Pattern Works

| Aspect | Benefit |
|--------|---------|
| **Dependencies respected** | Groups execute serially; Task 3 waits for Task 1 |
| **True parallelism** | Tasks in same group run simultaneously |
| **No context leak** | Task content passed to agents, not loaded into orchestrator |
| **Accurate progress** | `current_task` updated after confirmed group completion |
| **Resume works** | `current_task=2` means tasks 1-2 definitely done |

### 3d. Extracting Task Content

Use helper to get task content for agent prompt:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
TASK_CONTENT=$(get_task_content "$PLAN_FILE" 1)
echo "$TASK_CONTENT"
```

This extracts the full task section including TDD instructions without loading entire plan.

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
