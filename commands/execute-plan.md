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
    - label: "Sequential (Recommended)"
      description: "Execute tasks one by one with full TDD cycle"
    - label: "Parallel via swarm"
      description: "Use native swarm for independent tasks"
```

---

## Sequential Execution

### For Each Task:

**3a. Mark in_progress:**

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
STATE_FILE="$(get_state_file)"
CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
NEXT=$((CURRENT + 1))
echo "EXECUTING: Task $NEXT"
```

Mark task `in_progress` in TodoWrite.

**3b. Read Task Content:**

Extract task section from plan and read it.

**3c. Execute with TDD:**

Use `Skill("dev-workflow:test-driven-development")` to implement.

Follow the TDD cycle embedded in the task:
1. Write failing test
2. Run test, verify FAIL
3. Implement minimal code
4. Run test, verify PASS
5. Commit

**3d. Update State:**

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
STATE_FILE="$(get_state_file)"
CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
NEXT=$((CURRENT + 1))
frontmatter_set "$STATE_FILE" "current_task" "$NEXT"
echo "COMPLETED: Task $CURRENT, now at $NEXT"
```

Mark task `completed` in TodoWrite.

**3e. Continue to Next Task**

Repeat until all tasks complete.

---

## Parallel via Swarm

**3a. Analyze Parallel Groups:**

Read plan and identify tasks that can run in parallel (no file overlap).

**3b. Enter Plan Mode:**

Use `EnterPlanMode` to prepare for swarm execution.

**3c. Adapt Plan for Swarm:**

Write the plan content to the native plan file location. The plan is already in the correct format.

**3d. Launch Swarm:**

Calculate teammateCount from parallel groups:
- 1-2 groups: 2 teammates
- 3-4 groups: 3-4 teammates
- 5+ groups: 5 teammates (max)

```claude
ExitPlanMode:
  launchSwarm: true
  teammateCount: [calculated]
```

**3e. Wait for Swarm Completion:**

The swarm executes. `SubagentStop` hook updates `current_task` automatically.

**3f. Proceed to Post-Swarm Actions**

---

## Step 4: Post-Completion Actions (MANDATORY)

After ALL tasks complete, these steps are REQUIRED:

### 4a. Code Review

Mark "Code Review" `in_progress` in TodoWrite.

Dispatch code-reviewer:

```claude
Task:
  subagent_type: dev-workflow:code-reviewer
  description: "Review plan changes"
  prompt: |
    Review all changes from plan execution.

    git diff main..HEAD

    Focus on:
    - Cross-cutting concerns
    - Consistency across tasks
    - Test coverage
```

Use `Skill("dev-workflow:receiving-code-review")` to process feedback.

Mark "Code Review" `completed` in TodoWrite.

### 4b. Finish Branch

Mark "Finish Branch" `in_progress` in TodoWrite.

Use `Skill("dev-workflow:finishing-a-development-branch")`.

Mark "Finish Branch" `completed` in TodoWrite.

### 4c. Cleanup State

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
delete_state_file
echo "Workflow complete. State file deleted."
```

---

## Blocker Handling

If implementation hits a blocker:

```claude
AskUserQuestion:
  header: "Blocker"
  question: "Task $N blocked: [description]. What to do?"
  multiSelect: false
  options:
    - label: "Skip"
      description: "Mark incomplete, continue to next task"
    - label: "Retry"
      description: "Provide guidance to resolve"
    - label: "Stop"
      description: "Pause workflow, resume later"
```

**If Stop:** State file preserved. Resume with `/dev-workflow:resume`.

---

## Resume Capability

If session ends unexpectedly, next session will detect state file and prompt:

```
ACTIVE WORKFLOW DETECTED
Plan: docs/plans/...
Progress: 3/8 tasks

Commands:
- /dev-workflow:resume - Continue execution
- /dev-workflow:abandon - Discard workflow state
```
