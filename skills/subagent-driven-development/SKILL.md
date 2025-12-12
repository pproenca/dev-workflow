---
name: subagent-driven-development
description: Execute plan by dispatching fresh subagent per task with parallelization support. Use when asked to "use subagents", "execute in this session", "parallel tasks", or after `/dev-workflow:write-plan` when choosing subagent execution.
allowed-tools: Read, Write, Bash, Grep, Glob, TodoWrite, Task, Skill, AskUserQuestion
---

# Subagent-Driven Development

Execute plan by dispatching fresh subagent per task, with commit verification and code review at end.

## Execution Behavior

**This is a continuous workflow. Do not stop between steps.**

After loading this skill, execute all steps until "Workflow complete". Only permitted stops:

1. AskUserQuestion (wait for response, then continue)
2. Blocker requiring user input
3. Final completion report

**Critical:** After ANY tool call completes, immediately make the next tool call.

## Path Resolution

Resolve absolute paths at start:

```bash
STATE_FILE="$(git rev-parse --show-toplevel)/.claude/dev-workflow-state.local.md"
HANDOFF_FILE="$(git rev-parse --show-toplevel)/.claude/pending-handoff.local.md"
echo "STATE_FILE:$STATE_FILE"
```

## Concurrency

State file `$STATE_FILE` is worktree-scoped.

**Parallel executions:** Each must be in separate worktree.

## Prerequisites

1. **Session must use opus** - Orchestration requires opus-level reasoning
2. **Plan file must exist** - Use `/dev-workflow:write-plan` first

If session uses sonnet/haiku:

> This workflow requires opus. Switch to opus or use `/dev-workflow:execute-plan` instead.

## Step 1: Initialize

Determine plan file from handoff state or state file:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
if [[ -f "$HANDOFF_FILE" ]]; then
  PLAN_FILE="$(frontmatter_get "$HANDOFF_FILE" "plan" "")"
  rm -f "$HANDOFF_FILE"
elif [[ -f "$STATE_FILE" ]]; then
  PLAN_FILE="$(frontmatter_get "$STATE_FILE" "plan" "")"
fi
echo "PLAN_FILE:$PLAN_FILE"
```

If PLAN_FILE is empty, stop with error: "No plan file found. Run /dev-workflow:write-plan first."

Read plan file. Extract task count:

```bash
BASE_SHA=$(git rev-parse HEAD)
PLAN_ABS=$(realpath "$PLAN_FILE")
TOTAL_TASKS=$(grep -c "^### Task [0-9]\+:" "$PLAN_FILE")
```

Check for existing state:

```bash
test -f "$STATE_FILE" && echo "RESUME" || echo "NEW"
```

If RESUME: go to Resume Flow below.

If NEW, create state file:

```bash
mkdir -p "$(dirname "$STATE_FILE")"
cat > "$STATE_FILE" << EOF
---
workflow: subagent
plan: $PLAN_ABS
base_sha: $BASE_SHA
current_task: 0
total_tasks: $TOTAL_TASKS
last_commit: $BASE_SHA
enabled: true
---

$(basename "$PLAN_FILE" .md) - initializing
EOF
```

Extract task list for TodoWrite:

```bash
grep -E "^### Task [0-9]+:" "$PLAN_FILE" | sed 's/^### Task \([0-9]*\): \(.*\)/Task \1: \2/'
```

Use TodoWrite for all tasks + "Final Code Review" + "Finish Branch".

**Immediately proceed to Step 2.**

## Step 2: Analyze Dependencies

Extract file paths from each task section in the plan:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
PLAN="$(frontmatter_get "$STATE_FILE" "plan" "")"
awk '/^### Task [0-9]+:/,/^### Task [0-9]+:|^## /' "$PLAN" | \
  grep -E '(Create|Modify|Test):' | \
  grep -oE '`[^`]+`' | tr -d '`' | sort -u
```

**Build dependency model:**

For each pair of tasks, check if they share files:

- File overlap → Sequential (Task B after Task A)
- No overlap → Can parallelize

**Maximum 3 parallel subagents per batch.**

**Immediately proceed to Step 3.**

## Step 3: Execute Tasks

### 3a. Identify Next Task(s)

Read current position:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
CURRENT="$(frontmatter_get "$STATE_FILE" "current_task" "0")"
TOTAL="$(frontmatter_get "$STATE_FILE" "total_tasks" "0")"
```

If CURRENT >= TOTAL: skip to Step 4.

Determine next batch based on dependency analysis.

### 3b. Select Model Per Task

| Model  | Use For                                 |
| ------ | --------------------------------------- |
| haiku  | Simple tasks (<3 files, single concern) |
| sonnet | Standard tasks (default)                |
| opus   | Complex (5+ files, architecture)        |

### 3c. Dispatch Subagent(s)

**For sequential task:**

````
Task tool (general-purpose):
  model: [selected-model]
  prompt: |
    You are implementing Task $TASK_NUMBER of $TOTAL from plan: $PLAN_FILE

    ## Your Task
    $TASK_DESCRIPTION

    ## Instructions
    1. Read the plan file for full context
    2. Follow the TDD cycle in your task exactly (write failing test first)
    3. Run tests, verify they pass
    4. Commit with conventional format:
       ```
       feat(scope): description of change
       ```
       or fix(), test(), docs() as appropriate

    ## Constraints
    - Follow TDD steps in plan: test FIRST, then implement
    - Only implement this task
    - Do not modify files outside task scope
    - Tests must pass before commit
````

**For parallel batch:**

Dispatch multiple Task tools simultaneously for independent tasks.

### 3d. Verify Completion

After subagent returns, verify new commit exists:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
LAST_COMMIT="$(frontmatter_get "$STATE_FILE" "last_commit" "")"
CURRENT_HEAD="$(git rev-parse HEAD)"

if [[ "$LAST_COMMIT" != "$CURRENT_HEAD" ]]; then
  echo "COMMITTED"
else
  echo "NO_COMMIT"
fi
```

If NO_COMMIT:

> Subagent did not commit. Dispatching fix subagent.

Dispatch fix subagent with error context and instruction to debug systematically.

If COMMITTED:

Update state file:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
NEXT_TASK=$((CURRENT + 1))
frontmatter_set "$STATE_FILE" "current_task" "$NEXT_TASK"
frontmatter_set "$STATE_FILE" "last_commit" "$(git rev-parse HEAD)"
```

Mark task `completed` in TodoWrite.

### 3e. Continue

Return to 3a for next batch.

## Step 4: Final Code Review

After all tasks complete:

Mark "Final Code Review" `in_progress` in TodoWrite.

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
    Review all changes from implementation.
    Plan: [plan file]
    BASE_SHA: [from state]
    Focus: Cross-cutting concerns, architecture consistency.
```

Use `Skill("dev-workflow:receiving-code-review")` to process feedback.

Fix Critical issues before proceeding.

Mark "Final Code Review" `completed` in TodoWrite.

## Step 5: Finish

Mark "Finish Branch" `in_progress` in TodoWrite.

Use `Skill("dev-workflow:finishing-a-development-branch")`.

Remove state file:

```bash
rm -f "$STATE_FILE"
```

Mark "Finish Branch" `completed` in TodoWrite.

Report:

```text
✓ Plan executed: [N] tasks
✓ Tests: passing
✓ Code reviewed: [issues found/fixed]
✓ Branch: [merged/PR/kept]

Workflow complete.
```

## Resume Flow

When state file exists:

**1. Read state:**

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
PLAN="$(frontmatter_get "$STATE_FILE" "plan" "")"
CURRENT="$(frontmatter_get "$STATE_FILE" "current_task" "0")"
TOTAL="$(frontmatter_get "$STATE_FILE" "total_tasks" "0")"
```

**2. Verify plan exists:**

```bash
test -f "$PLAN" || echo "Plan file missing: $PLAN"
```

**3. Rebuild TodoWrite** based on current_task position.

**4. Continue from Step 3** (3a will find next task).

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

## Red Flags

**Never:**

- Skip Final Code Review
- Proceed with Critical issues unfixed
- Dispatch parallel subagents on overlapping files
- Mark task complete without commit verification
- Use task-indexed commit messages

**If subagent fails:**

- Check git status for uncommitted changes
- Dispatch fix subagent with error context
- Do not attempt manual fix (context pollution)
