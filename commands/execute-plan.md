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

## Parallel Execution

Uses native `Task(run_in_background: true)` + `TaskOutput` pattern for concurrent agents.

### 3a. Analyze Task Groups

Identify tasks that can run in parallel (no file overlap):

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
PLAN_FILE="$ARGUMENTS"
TOTAL=$(frontmatter_get "$(get_state_file)" "total_tasks" "0")

# Group tasks by file dependencies (max 5 per group)
GROUPS=$(group_tasks_by_dependency "$PLAN_FILE" "$TOTAL" 5)
echo "PARALLEL_GROUPS: $GROUPS"
# Format: group1:1,2,3|group2:4,5|group3:6,7,8
```

### 3b. Execute Each Group

For each group, execute tasks in parallel:

#### Extract Tasks for Current Group

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
STATE_FILE="$(get_state_file)"
CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
PLAN_FILE=$(frontmatter_get "$STATE_FILE" "plan" "")

# Find next group to execute
# ... parse GROUPS to find tasks after CURRENT
```

#### Dispatch Group with Background Agents

**CRITICAL:** Send ALL Task calls for the group in a SINGLE message. This enables true parallel execution.

For a group with tasks 1, 2, 3:

```claude
# Send ONE message with MULTIPLE Task calls:

Task:
  subagent_type: general-purpose
  description: "Execute Task 1"
  model: sonnet
  run_in_background: true
  prompt: |
    Execute Task 1 from the plan.

    PLAN_FILE: [path]
    TASK_NUMBER: 1

    Instructions:
    1. Read task section from plan
    2. Follow TDD: write failing test, implement, verify pass
    3. Commit: git add -A && git commit -m "feat(scope): description"
    4. Return: "TASK 1 COMPLETE" or "TASK 1 FAILED: [reason]"

    Use Skill("dev-workflow:test-driven-development") for implementation.

Task:
  subagent_type: general-purpose
  description: "Execute Task 2"
  model: sonnet
  run_in_background: true
  prompt: |
    Execute Task 2 from the plan.
    [same structure...]

Task:
  subagent_type: general-purpose
  description: "Execute Task 3"
  model: sonnet
  run_in_background: true
  prompt: |
    Execute Task 3 from the plan.
    [same structure...]
```

Each Task call returns a `task_id`. Store these for the next step.

#### Wait for Group Completion

**CRITICAL:** Send ALL TaskOutput calls in a SINGLE message to wait concurrently.

```claude
# Send ONE message with MULTIPLE TaskOutput calls:

TaskOutput:
  task_id: [task_id_1]
  block: true
  timeout: 300000

TaskOutput:
  task_id: [task_id_2]
  block: true
  timeout: 300000

TaskOutput:
  task_id: [task_id_3]
  block: true
  timeout: 300000
```

All three wait concurrently. Terminal remains responsive.

**Note:** The `SubagentStop` hook automatically updates `current_task` in the state file when each agent completes.

#### Process Results and Continue

After all TaskOutput calls return:
1. Check results for failures
2. Mark tasks `completed` in TodoWrite
3. If more groups remain, continue to next group
4. If all groups complete, proceed to Post-Completion Actions

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
