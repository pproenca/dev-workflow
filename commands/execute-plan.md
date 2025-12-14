---
description: Execute implementation plan with progress tracking and post-completion actions
argument-hint: [plan-file]
allowed-tools: Read, Write, Bash, TodoWrite, Task, Skill, AskUserQuestion
---

# Execute Plan

Execute implementation plan with state tracking and mandatory post-completion actions.

**Model Requirements:**
- Orchestrator (this command): **Opus 4.5** - handles planning decisions, state management, coordination
- Task execution agents: **Sonnet** - handles individual task implementation (TDD cycles)

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
grep -E "^### Task [0-9]+(\.[0-9]+)?:" "$PLAN_FILE" | sed 's/^### Task \([0-9.]*\): \(.*\)/Task \1: \2/'
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

Execute tasks one by one using background agents (keeps orchestrator context minimal).

### 3a. Check for Interrupted Dispatch (Compact Recovery)

Same as parallel execution - check if a previous task was interrupted:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
STATE_FILE="$(get_state_file)"
DISPATCHED_AGENTS=$(frontmatter_get "$STATE_FILE" "agent_ids" "")

if [[ -n "$DISPATCHED_AGENTS" ]]; then
  echo "RECOVERING: Resuming interrupted task with agent $DISPATCHED_AGENTS"
fi
```

If `DISPATCHED_AGENTS` is not empty, call `TaskOutput` for that agent, then clear state and continue.

### 3b. Execute Each Task

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
STATE_FILE="$(get_state_file)"
CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
NEXT=$((CURRENT + 1))
echo "EXECUTING: Task $NEXT"
```

Mark task `in_progress` in TodoWrite.

Launch task in background:

```claude
Task:
  subagent_type: general-purpose
  model: sonnet
  description: "Execute Task [N]"
  prompt: |
    Execute Task [N] from plan. Follow TDD instructions exactly.
    [Task content extracted via get_task_content]
  run_in_background: true
```

Persist state immediately:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
STATE_FILE="$(get_state_file)"
frontmatter_set "$STATE_FILE" "dispatched_group" "sequential:$NEXT"
frontmatter_set "$STATE_FILE" "agent_ids" "[agent_id]"
```

Wait for completion:

```claude
TaskOutput:
  task_id: [agent_id]
  block: true
```

### 3c. Update State After Each Task

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
STATE_FILE="$(get_state_file)"
CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
frontmatter_set "$STATE_FILE" "dispatched_group" ""
frontmatter_set "$STATE_FILE" "agent_ids" ""
frontmatter_set "$STATE_FILE" "current_task" "$((CURRENT + 1))"
```

Mark task `completed` in TodoWrite. Continue to next task.

---

## Parallel Execution (Background Agents)

Uses `Task(run_in_background)` + `TaskOutput` pattern from tools.md to execute tasks in parallel while respecting dependencies.

### 3a. Check for Interrupted Dispatch (Compact Recovery)

**CRITICAL:** Before analyzing groups, check if a previous dispatch was interrupted by compaction:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
STATE_FILE="$(get_state_file)"
DISPATCHED_AGENTS=$(frontmatter_get "$STATE_FILE" "agent_ids" "")
DISPATCHED_GROUP=$(frontmatter_get "$STATE_FILE" "dispatched_group" "")

echo "DISPATCHED_AGENTS: $DISPATCHED_AGENTS"
echo "DISPATCHED_GROUP: $DISPATCHED_GROUP"
```

**If `DISPATCHED_AGENTS` is not empty:** Agents were launched but TaskOutput was interrupted. Resume waiting:

1. Parse agent IDs from `DISPATCHED_AGENTS` (comma-separated)
2. Call `TaskOutput` for each agent ID (they may already be complete - results return immediately)
3. Clear dispatched state after all TaskOutput calls return:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
STATE_FILE="$(get_state_file)"
frontmatter_set "$STATE_FILE" "dispatched_group" ""
frontmatter_set "$STATE_FILE" "agent_ids" ""
# Update current_task to last task in recovered group
frontmatter_set "$STATE_FILE" "current_task" "[LAST_TASK_IN_RECOVERED_GROUP]"
```

4. Continue to next group (skip re-analyzing, use state's `current_task` to determine progress)

### 3b. Analyze Task Groups

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
PLAN_FILE="$ARGUMENTS"

# Group tasks by file dependencies
# Tasks in same group have NO file overlap → can run parallel
# Groups execute serially (group1 completes before group2 starts)
TASK_GROUPS=$(group_tasks_by_dependency "$PLAN_FILE" 5)
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
  model: sonnet
  description: "Execute Task 1"
  prompt: |
    Execute Task 1 from plan. Follow TDD instructions exactly.
    [Task 1 content extracted via get_task_content]
  run_in_background: true

Task:
  subagent_type: general-purpose
  model: sonnet
  description: "Execute Task 2"
  prompt: |
    Execute Task 2 from plan. Follow TDD instructions exactly.
    [Task 2 content extracted via get_task_content]
  run_in_background: true
```

2. **IMMEDIATELY persist agent IDs to state** (before calling TaskOutput):

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
STATE_FILE="$(get_state_file)"
# Persist agent IDs so they survive compaction
frontmatter_set "$STATE_FILE" "dispatched_group" "group1:1,2"
frontmatter_set "$STATE_FILE" "agent_ids" "agent_id_1,agent_id_2"
echo "STATE PERSISTED: dispatched_group and agent_ids saved"
```

3. Wait for ALL agents in the group to complete:

```claude
# Wait for all background agents
TaskOutput:
  task_id: [agent_id_1]
  block: true

TaskOutput:
  task_id: [agent_id_2]
  block: true
```

4. Update state after group completes (clear dispatched, update current_task):

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
STATE_FILE="$(get_state_file)"
# Clear dispatched state now that group is complete
frontmatter_set "$STATE_FILE" "dispatched_group" ""
frontmatter_set "$STATE_FILE" "agent_ids" ""
# Set to last task number in completed group
frontmatter_set "$STATE_FILE" "current_task" "[LAST_TASK_IN_GROUP]"
```

5. Mark completed tasks in TodoWrite.

**If group has single task** (e.g., `group3:5`):

Still use background execution to keep orchestrator context minimal:

```claude
Task:
  subagent_type: general-purpose
  model: sonnet
  description: "Execute Task 5"
  prompt: |
    Execute Task 5 from plan. Follow TDD instructions exactly.
    [Task 5 content]
  run_in_background: true
```

Then persist state, wait, and update (same pattern as multi-task groups):

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
STATE_FILE="$(get_state_file)"
frontmatter_set "$STATE_FILE" "dispatched_group" "group3:5"
frontmatter_set "$STATE_FILE" "agent_ids" "[agent_id]"
```

```claude
TaskOutput:
  task_id: [agent_id]
  block: true
```

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
STATE_FILE="$(get_state_file)"
frontmatter_set "$STATE_FILE" "dispatched_group" ""
frontmatter_set "$STATE_FILE" "agent_ids" ""
frontmatter_set "$STATE_FILE" "current_task" "5"
```

Update TodoWrite after completion.

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
  model: opus
  run_in_background: true
  description: "Review all changes"
  prompt: |
    Review all changes from plan execution.
    Run: git diff main..HEAD
    Focus on cross-cutting concerns and consistency.
```

Wait for results:

```claude
TaskOutput:
  task_id: <code-reviewer-task-id>
  block: true
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
