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

## Execution Behavior

**This is a continuous workflow within each batch.**

Execute steps in sequence. The only permitted stops are:

1. AskUserQuestion prompts (wait for user, then continue)
2. Batch checkpoint (pause for human review)
3. Final completion report

**Do not narrate between tool calls. Do not summarize progress mid-batch.**

## Concurrency

State file is worktree-scoped (`.claude/dev-workflow-state.local.md`).

**Parallel executions:** Each must be in separate worktree.
**Same worktree:** Only one execution at a time.

---

## MANDATORY FIRST ACTION: Worktree Check

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/worktree-manager.sh"
PLAN_FILE="$ARGUMENTS"
PLAN_ABS="$(realpath "$PLAN_FILE")"
IS_MAIN=$(is_main_repo && echo "true" || echo "false")
echo "PLAN_ABS:$PLAN_ABS"
echo "IS_MAIN_REPO:$IS_MAIN"
```

| IS_MAIN_REPO | Action                       |
| ------------ | ---------------------------- |
| `true`       | Go to **Worktree Setup**     |
| `false`      | Go to **Step 1: Initialize** |

---

## Worktree Setup

**You are in the main repository. Create an isolated worktree before execution.**

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/worktree-manager.sh"
PLAN_ABS="$(realpath "$ARGUMENTS")"
WORKTREE_PATH="$(setup_worktree_with_state "$PLAN_ABS" "execute-plan")"
STATE_FILE="${WORKTREE_PATH}/.claude/dev-workflow-state.local.md"

echo "WORKTREE_PATH:$WORKTREE_PATH"
echo "STATE_FILE:$STATE_FILE"
```

**Choose execution method:**

```claude
AskUserQuestion:
  header: "Execute"
  question: "Worktree created at $WORKTREE_PATH. How to proceed?"
  multiSelect: false
  options:
    - label: "Subagents"
      description: "Dispatch opus subagent to execute in worktree"
    - label: "New terminal"
      description: "Open Terminal.app in worktree"
    - label: "Cancel"
      description: "Keep worktree, don't execute"
```

**If "Subagents" selected:**

Update workflow type and batch size in state:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
frontmatter_set "$STATE_FILE" "workflow" "subagent"
frontmatter_set "$STATE_FILE" "batch_size" "5"
```

### Batch Execution Loop

Execute tasks in batches with fresh orchestrators to prevent memory exhaustion.

**Check remaining tasks:**

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
TOTAL=$(frontmatter_get "$STATE_FILE" "total_tasks" "0")
BATCH_SIZE=$(frontmatter_get "$STATE_FILE" "batch_size" "5")
BATCH_END=$((CURRENT + BATCH_SIZE))
[[ $BATCH_END -gt $TOTAL ]] && BATCH_END=$TOTAL
echo "BATCH:tasks $((CURRENT+1)) to $BATCH_END of $TOTAL"
```

**While CURRENT < TOTAL:**

Dispatch bounded batch orchestrator:

```claude
Task tool:
  model: opus
  prompt: |
    Execute BATCH of tasks (not full plan).

    ## EXPLICIT PATHS (use these, do not discover)

    WORKTREE_PATH: [WORKTREE_PATH]
    STATE_FILE: [STATE_FILE]
    PLAN_FILE: [PLAN_ABS]

    ## INSTRUCTIONS

    1. cd "[WORKTREE_PATH]"
    2. cat "[STATE_FILE]"
    3. Skill("dev-workflow:subagent-driven-development")

    Execute until batch boundary (calculated from batch_size in state).
    Do NOT proceed to Final Code Review (caller handles that).
```

After batch returns, check progress:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
TOTAL=$(frontmatter_get "$STATE_FILE" "total_tasks" "0")
echo "PROGRESS:$CURRENT/$TOTAL"
```

**If CURRENT < TOTAL:** Loop back to "Check remaining tasks" (spawns fresh orchestrator).

**If CURRENT >= TOTAL:** Proceed to **Step 6: Final Code Review**.

**If "New terminal" selected:**

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/open-terminal.sh" "$WORKTREE_PATH"
echo "LAUNCHED:$WORKTREE_PATH"
```

Report success and **STOP**. The new session continues in Terminal.app.

**If "Cancel" selected:**

Report worktree location:

```text
Worktree created at: [WORKTREE_PATH]

To remove if not needed:
  git worktree remove [WORKTREE_PATH]
```

**STOP**.

---

## Step 1: Initialize

**You are already in a worktree (IS_MAIN_REPO was false).**

**FIRST:** Double-check we're not in main repo (safety validation):

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/worktree-manager.sh"
if is_main_repo; then
  echo "ERROR: In main repo. Go back to Worktree Setup section."
  exit 1
fi
WORKTREE_PATH="$(get_repo_root)"
STATE_FILE="${WORKTREE_PATH}/.claude/dev-workflow-state.local.md"
echo "WORKTREE_PATH:$WORKTREE_PATH"
echo "STATE_FILE:$STATE_FILE"
test -f "$STATE_FILE" && echo "FOUND" || echo "NOT_FOUND"
```

**If ERROR about main repo:** You're in the wrong place. Return to **Worktree Setup** section above.

**If NOT_FOUND:** State file should exist in any worktree created by the workflow. This indicates one of:

1. **Wrong directory** - Verify you're in the correct worktree (check `is_main_repo` returned false above)
2. **Manual worktree** - If this is a manually created worktree without state, create it:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/worktree-manager.sh"
# Safety: refuse to create state in main repo
if is_main_repo; then
  echo "ERROR: Cannot create state in main repo. Use Worktree Setup section."
  exit 1
fi
PLAN_ABS="$(realpath "$ARGUMENTS")"
WORKTREE_PATH="$(get_repo_root)"
TOTAL_TASKS=$(grep -c "^### Task [0-9]\+:" "$PLAN_ABS")
BASE_SHA=$(git rev-parse HEAD)
STATE_FILE="${WORKTREE_PATH}/.claude/dev-workflow-state.local.md"

mkdir -p "${WORKTREE_PATH}/.claude"
cat > "$STATE_FILE" << EOF
---
workflow: execute-plan
worktree: $WORKTREE_PATH
plan: $PLAN_ABS
base_sha: $BASE_SHA
current_task: 0
total_tasks: $TOTAL_TASKS
last_commit: $BASE_SHA
batch_size: 5
enabled: true
---
EOF
echo "STATE_FILE:$STATE_FILE"
```

**Read state:**

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
WORKTREE=$(frontmatter_get "$STATE_FILE" "worktree" "")
PLAN=$(frontmatter_get "$STATE_FILE" "plan" "")
CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
TOTAL=$(frontmatter_get "$STATE_FILE" "total_tasks" "0")
ENABLED=$(frontmatter_get "$STATE_FILE" "enabled" "true")
echo "WORKTREE:$WORKTREE"
echo "PLAN:$PLAN"
echo "PROGRESS:$CURRENT/$TOTAL"
echo "ENABLED:$ENABLED"
```

**If ENABLED is false:** Ask user if they want to continue.

**If CURRENT > 0:** This is a resume - rebuild TodoWrite from current position.

Extract task list for TodoWrite:

```bash
grep -E "^### Task [0-9]+:" "$PLAN" | sed 's/^### Task \([0-9]*\): \(.*\)/Task \1: \2/'
```

Use TodoWrite for: all tasks + "Final Code Review" + "Finish Branch".

## Step 2: Choose Mode

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
```

**If Subagents:**

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
frontmatter_set "$STATE_FILE" "workflow" "subagent"
frontmatter_set "$STATE_FILE" "batch_size" "5"
```

### Batch Execution Loop (in worktree)

Execute tasks in batches with fresh orchestrators to prevent memory exhaustion.

**Check remaining tasks:**

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
TOTAL=$(frontmatter_get "$STATE_FILE" "total_tasks" "0")
BATCH_SIZE=$(frontmatter_get "$STATE_FILE" "batch_size" "5")
BATCH_END=$((CURRENT + BATCH_SIZE))
[[ $BATCH_END -gt $TOTAL ]] && BATCH_END=$TOTAL
WORKTREE_PATH=$(frontmatter_get "$STATE_FILE" "worktree" "")
PLAN_FILE=$(frontmatter_get "$STATE_FILE" "plan" "")
echo "BATCH:tasks $((CURRENT+1)) to $BATCH_END of $TOTAL"
echo "WORKTREE_PATH:$WORKTREE_PATH"
echo "STATE_FILE:$STATE_FILE"
echo "PLAN_FILE:$PLAN_FILE"
```

**While CURRENT < TOTAL:**

Dispatch bounded batch orchestrator:

```claude
Task tool:
  model: opus
  prompt: |
    Execute BATCH of tasks (not full plan).

    ## EXPLICIT PATHS (use these, do not discover)

    WORKTREE_PATH: [WORKTREE_PATH]
    STATE_FILE: [STATE_FILE]
    PLAN_FILE: [PLAN_FILE]

    ## INSTRUCTIONS

    1. cd "[WORKTREE_PATH]"
    2. cat "[STATE_FILE]"
    3. Skill("dev-workflow:subagent-driven-development")

    Execute until batch boundary (calculated from batch_size in state).
    Do NOT proceed to Final Code Review (caller handles that).
```

After batch returns, check progress:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
TOTAL=$(frontmatter_get "$STATE_FILE" "total_tasks" "0")
echo "PROGRESS:$CURRENT/$TOTAL"
```

**If CURRENT < TOTAL:** Loop back to "Check remaining tasks" (spawns fresh orchestrator).

**If CURRENT >= TOTAL:** Proceed to **Step 6: Final Code Review**.

**If This session:** Continue to Step 3.

## Step 3: Analyze Dependencies

Extract file paths from each task section:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
PLAN="$(frontmatter_get "$STATE_FILE" "plan" "")"
awk '/^### Task [0-9]+:/,/^### Task [0-9]+:|^## /' "$PLAN" | \
  grep -E '(Create|Modify|Test):' | \
  grep -oE '`[^`]+`' | tr -d '`' | sort -u
```

Build mental model of task dependencies for batching. Tasks sharing files must be sequential.

## Step 4: Execute Tasks (Sequential)

For each task:

### 4a. Read position

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
TOTAL=$(frontmatter_get "$STATE_FILE" "total_tasks" "0")
NEXT=$((CURRENT + 1))
echo "EXECUTING:Task $NEXT of $TOTAL"
```

Mark task `in_progress` in TodoWrite.

### 4b. Implement

Read task from plan. Follow TDD: write failing test first, then implement.

Run tests:

```bash
if [ -f package.json ]; then npm test
elif [ -f pytest.ini ] || [ -f pyproject.toml ]; then pytest
elif [ -f Cargo.toml ]; then cargo test
else echo "NO_TEST_COMMAND"; fi
```

If tests fail: fix before proceeding.

### 4c. Commit

```bash
git add -A
git commit -m "feat(scope): description"
```

### 4d. Update state

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
NEXT=$((CURRENT + 1))
frontmatter_set "$STATE_FILE" "current_task" "$NEXT"
frontmatter_set "$STATE_FILE" "last_commit" "$(git rev-parse HEAD)"
```

Mark task `completed` in TodoWrite.

### 4e. Batch checkpoint (every 3 tasks)

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

Mark "Final Code Review" `in_progress` in TodoWrite.

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
BASE_SHA=$(frontmatter_get "$STATE_FILE" "base_sha" "")
WORKTREE=$(frontmatter_get "$STATE_FILE" "worktree" "")
PLAN=$(frontmatter_get "$STATE_FILE" "plan" "")
git diff "$BASE_SHA"..HEAD --stat
```

Dispatch code-reviewer with explicit paths:

```claude
Task tool (dev-workflow:code-reviewer):
  model: sonnet
  prompt: |
    Review changes from this plan.
    WORKTREE_PATH: [WORKTREE]
    PLAN_FILE: [PLAN]
    BASE_SHA: [BASE_SHA]
    First: cd "[WORKTREE_PATH]"
    Then: git diff [BASE_SHA]..HEAD
    Focus: Cross-cutting concerns, consistency.
```

Use `Skill("dev-workflow:receiving-code-review")` to process feedback.

Mark "Final Code Review" `completed` in TodoWrite.

## Step 7: Finish

Mark "Finish Branch" `in_progress` in TodoWrite.

Use `Skill("dev-workflow:finishing-a-development-branch")`.

```bash
rm -f "$STATE_FILE"
```

Mark "Finish Branch" `completed` in TodoWrite.

---

## Recovery

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
STATE_FILE="[path]"

# View
cat "$STATE_FILE"

# Rollback
BASE_SHA=$(frontmatter_get "$STATE_FILE" "base_sha" "")
git reset --hard "$BASE_SHA"
rm "$STATE_FILE"
```

## Integration

| Component                                  | How execute-plan uses it                 |
| ------------------------------------------ | ---------------------------------------- |
| `dev-workflow:subagent-driven-development` | Step 2: "Subagents" mode handoff         |
| `dev-workflow:code-reviewer`               | Step 6: Final code review                |
| `dev-workflow:receiving-code-review`       | Step 6: Process review feedback          |
| `dev-workflow:finishing-a-development-branch` | Step 7: Branch completion             |
