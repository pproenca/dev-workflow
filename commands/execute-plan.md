---
description: Execute implementation plan with batch checkpoints and human review between batches
argument-hint: [plan-file]
allowed-tools: Read, Write, Bash, TodoWrite, Task, Skill, AskUserQuestion
---

# Execute Plan

Execute implementation plan with batch checkpoints.

## Input

$ARGUMENTS

**If empty or file not found:** Stop with error "Plan file not found or not specified"

## Path Resolution

```bash
STATE_FILE="$(git rev-parse --show-toplevel)/.claude/dev-workflow-state.local.md"
echo "STATE_FILE:$STATE_FILE"
```

## Execution Behavior

**This is a continuous workflow within each batch.**

Execute steps in sequence. The only permitted stops are:

1. AskUserQuestion prompts (wait for user, then continue)
2. Batch checkpoint (pause for human review)
3. Final completion report

**Do not narrate between tool calls. Do not summarize progress mid-batch.**

## Concurrency

State file `$STATE_FILE` is worktree-scoped.

**Parallel executions:** Each must be in separate worktree.
**Same worktree:** Only one execution at a time.

---

## MANDATORY FIRST ACTION: Worktree Check

**BEFORE ANY OTHER STEP**, run this check:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/worktree-manager.sh"
IS_MAIN=$(is_main_repo && echo "true" || echo "false")
echo "IS_MAIN_REPO:$IS_MAIN"
```

**Decision based on output:**

| Output               | Action                                  |
| -------------------- | --------------------------------------- |
| `IS_MAIN_REPO:true`  | **STOP. Go to Worktree Setup below.**   |
| `IS_MAIN_REPO:false` | Proceed to Step 1 (already in worktree) |

---

## Worktree Setup (when IS_MAIN_REPO:true)

**You are in the main repository. Create an isolated worktree before execution.**

### Create worktree

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/worktree-manager.sh"
PLAN_FILE="$ARGUMENTS"
WORKTREE_PATH="$(setup_worktree_with_handoff "$PLAN_FILE" "pending")"
echo "✓ Worktree created: $WORKTREE_PATH"
```

### Ask how to proceed

Use AskUserQuestion:

```claude
AskUserQuestion:
  header: "Continue"
  question: "Worktree created at $WORKTREE_PATH. How should execution proceed?"
  multiSelect: false
  options:
    - label: "Continue here"
      description: "Switch to worktree and execute with subagents"
    - label: "New terminal"
      description: "Auto-open Terminal.app in worktree"
```

### If "Continue here" selected:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/worktree-manager.sh"
WORKTREE_PATH="$(activate_worktree "subagent")"
cd "$WORKTREE_PATH"
echo "READY:$WORKTREE_PATH"
```

Use `Skill("dev-workflow:subagent-driven-development")`. Skill reads plan from handoff.

**STOP HERE.** The skill takes over execution.

### If "New terminal" selected:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/worktree-manager.sh"
WORKTREE_PATH="$(activate_worktree "subagent")"
"${CLAUDE_PLUGIN_ROOT}/scripts/open-terminal.sh" "$WORKTREE_PATH"
echo "LAUNCHED:$WORKTREE_PATH"
```

Report success and **STOP HERE**. The new session continues in Terminal.app.

---

## Step 1: Initialize

**Only reach this step if IS_MAIN_REPO was false (already in worktree).**

Plan file: `$ARGUMENTS`

Verify plan exists:

```bash
test -f "$ARGUMENTS" && echo "EXISTS" || echo "MISSING"
```

If MISSING: stop with error.

Check for existing state:

```bash
test -f "$STATE_FILE" && echo "RESUME" || echo "NEW"
```

If RESUME: Read state file and go to Resume Flow below.

If NEW:

Capture baseline and count tasks:

```bash
BASE_SHA=$(git rev-parse HEAD)
PLAN_ABS=$(realpath "$ARGUMENTS")
TOTAL_TASKS=$(grep -c "^### Task [0-9]\+:" "$ARGUMENTS")

mkdir -p .claude
```

Create state file:

```bash
mkdir -p "$(dirname "$STATE_FILE")"
cat > "$STATE_FILE" << EOF
---
workflow: execute-plan
plan: $PLAN_ABS
base_sha: $BASE_SHA
current_task: 0
total_tasks: $TOTAL_TASKS
last_commit: $BASE_SHA
enabled: true
---

$(basename "$ARGUMENTS" .md) - initializing
EOF
```

Extract task list for TodoWrite:

```bash
grep -E "^### Task [0-9]+:" "$ARGUMENTS" | sed 's/^### Task \([0-9]*\): \(.*\)/Task \1: \2/'
```

Use TodoWrite to create items for: all plan tasks + "Final Code Review" + "Finish Branch".

**Immediately proceed to Step 2.**

## Step 2: Choose Execution Mode

Use AskUserQuestion:

```claude
AskUserQuestion:
  header: "Mode"
  question: "How should tasks be executed?"
  multiSelect: false
  options:
    - label: "Subagents"
      description: "Fresh context per task, faster execution"
    - label: "This session"
      description: "Sequential in current context, more control"
    - label: "Parallel session"
      description: "Open new terminal, manual coordination"
```

If Subagents:

Update state file:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
frontmatter_set "$STATE_FILE" "workflow" "subagent"
```

Use `Skill("dev-workflow:subagent-driven-development")` with plan file. Skill takes over.

If This session:

Proceed to Step 3.

If Parallel session:

Report worktree path and instructions. Stop.

## Step 3: Analyze Dependencies

Read plan file, extract file paths from each task:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
PLAN="$(frontmatter_get "$STATE_FILE" "plan" "")"
awk '/^### Task [0-9]+:/,/^### Task [0-9]+:|^## /' "$PLAN" | \
  grep -E '(Create|Modify|Test):' | \
  grep -oE '`[^`]+`' | tr -d '`' | sort -u
```

Build mental model of task dependencies for batching. Tasks sharing files must be sequential.

**Immediately proceed to Step 4.**

## Step 4: Execute Tasks (Sequential Mode)

For each task:

### 4a. Read current position

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
CURRENT="$(frontmatter_get "$STATE_FILE" "current_task" "0")"
NEXT=$((CURRENT + 1))
```

Mark task `in_progress` in TodoWrite.

### 4b. Implement task

Read task details from plan. Implement completely.

Run tests:

```bash
if [ -f package.json ]; then npm test
elif [ -f pytest.ini ] || [ -f pyproject.toml ]; then pytest
elif [ -f Cargo.toml ]; then cargo test
else echo "NO_TEST_COMMAND"; fi
```

If tests fail: fix before proceeding.

### 4c. Commit with conventional format

```bash
# Use conventional commits - NOT task-indexed
git add -A
git commit -m "feat(scope): description of change"
```

### 4d. Update state

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
NEXT_TASK=$((CURRENT + 1))
frontmatter_set "$STATE_FILE" "current_task" "$NEXT_TASK"
frontmatter_set "$STATE_FILE" "last_commit" "$(git rev-parse HEAD)"
```

Mark task `completed` in TodoWrite.

### 4e. Batch checkpoint

After every 3 tasks:

Use AskUserQuestion:

```claude
AskUserQuestion:
  header: "Checkpoint"
  question: "Batch complete. $COMPLETED/$TOTAL tasks done. Continue?"
  multiSelect: false
  options:
    - label: "Continue"
      description: "Proceed to next batch"
    - label: "Review"
      description: "Show git log and diff before continuing"
    - label: "Pause"
      description: "Stop here, can resume later"
```

If Pause: stop. State preserved for resume.

## Step 5: Handle Blocker

If implementation hits a blocker:

Use AskUserQuestion:

```claude
AskUserQuestion:
  header: "Blocker"
  question: "Task $N: [type] - [description]"
  multiSelect: false
  options:
    - label: "Skip"
      description: "Mark incomplete and continue to next task"
    - label: "Retry"
      description: "Provide guidance to help resolve the blocker"
    - label: "Stop"
      description: "Exit and preserve state for later"
```

## Step 6: Final Code Review

After all tasks complete:

Mark "Final Code Review" as `in_progress` in TodoWrite.

Read BASE_SHA from state file:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
BASE_SHA="$(frontmatter_get "$STATE_FILE" "base_sha" "")"
git diff "$BASE_SHA"..HEAD
```

Dispatch code-reviewer:

```claude
Task tool (dev-workflow:code-reviewer):
  model: sonnet
  prompt: |
    Review changes from this plan.
    Plan: [plan file]
    BASE_SHA: [from state]
    Focus: Cross-cutting concerns, consistency.
```

Use `Skill("dev-workflow:receiving-code-review")` to process feedback.

Mark "Final Code Review" as `completed` in TodoWrite.

## Step 7: Finish

Mark "Finish Branch" as `in_progress` in TodoWrite.

Use `Skill("dev-workflow:finishing-a-development-branch")`.

Remove state file:

```bash
rm -f "$STATE_FILE"
```

Mark "Finish Branch" as `completed` in TodoWrite.

## Resume Flow

When state file exists at Step 1:

**1. Read state:**

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
PLAN="$(frontmatter_get "$STATE_FILE" "plan" "")"
CURRENT="$(frontmatter_get "$STATE_FILE" "current_task" "0")"
TOTAL="$(frontmatter_get "$STATE_FILE" "total_tasks" "0")"
ENABLED="$(frontmatter_get "$STATE_FILE" "enabled" "true")"
```

**2. Verify enabled:**

If `enabled: false`, ask user if they want to continue.

**3. Verify plan exists:**

```bash
test -f "$PLAN" || echo "Plan file missing: $PLAN"
```

**4. Rebuild TodoWrite** based on current_task position.

**5. Resume from current_task.**

## Recovery

**View state:**

```bash
cat "$STATE_FILE"
```

**Rollback:**

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
BASE_SHA="$(frontmatter_get "$STATE_FILE" "base_sha" "")"
git reset --hard "$BASE_SHA"
rm "$STATE_FILE"
```

**Force restart:**

```bash
rm "$STATE_FILE"
```

## Integration

| Component                                  | How execute-plan uses it                     |
| ------------------------------------------ | -------------------------------------------- |
| `dev-workflow:code-explorer`               | Step 2: Codebase survey (via write-plan)     |
| `dev-workflow:code-architect`              | Step 4: Architecture design (via write-plan) |
| `dev-workflow:subagent-driven-development` | Step 2: "Subagents" mode handoff             |
| `dev-workflow:code-reviewer`               | Step 6: Final code review                    |
| `/dev-workflow:brainstorm`                 | Upstream: Creates design docs                |
