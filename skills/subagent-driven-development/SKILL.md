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

**Critical:** After ANY tool call completes, immediately make the next tool call. Do not narrate between tool calls.

## Concurrency

State file is worktree-scoped (`.claude/dev-workflow-state.local.md`).

**Parallel executions:** Each must be in separate worktree.
**Maximum 3 parallel subagents** per batch.

## Prerequisites

Before this skill loads, you should have received:

- `WORKTREE_PATH` - absolute path to the worktree
- `STATE_FILE` - absolute path to state file
- `PLAN_FILE` - absolute path to plan (also in state file)

**If you don't have these paths:** Stop and report error. The caller must provide explicit paths.

**Model requirement:** Orchestration requires opus-level reasoning. If session uses sonnet/haiku, consider using `/dev-workflow:execute-plan` instead for sequential execution.

## Step 0: Establish Context

**FIRST**, change to the worktree and verify state:

```bash
# Use the WORKTREE_PATH from your prompt
cd "[WORKTREE_PATH]"
pwd

# Verify state file
cat "[STATE_FILE]"
```

Read the state file to extract all paths:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
STATE_FILE="[STATE_FILE from your prompt]"

WORKTREE=$(frontmatter_get "$STATE_FILE" "worktree" "")
PLAN=$(frontmatter_get "$STATE_FILE" "plan" "")
CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
TOTAL=$(frontmatter_get "$STATE_FILE" "total_tasks" "0")
BASE_SHA=$(frontmatter_get "$STATE_FILE" "base_sha" "")

echo "WORKTREE:$WORKTREE"
echo "PLAN:$PLAN"
echo "PROGRESS:$CURRENT/$TOTAL"
```

**Store these values - you will pass them to every subagent.**

## Step 1: Setup TodoWrite

Extract tasks and create TodoWrite items:

```bash
grep -E "^### Task [0-9]+:" "$PLAN" | sed 's/^### Task \([0-9]*\): \(.*\)/Task \1: \2/'
```

Use TodoWrite for: all tasks + "Final Code Review" + "Finish Branch".

## Step 2: Analyze Dependencies

```bash
awk '/^### Task [0-9]+:/,/^### Task [0-9]+:|^## /' "$PLAN" | \
  grep -E '(Create|Modify|Test):' | \
  grep -oE '`[^`]+`' | tr -d '`' | sort -u
```

Build dependency model:

- File overlap → Sequential
- No overlap → Can parallelize (max 3)

## Step 3: Execute Tasks

### 3a. Check Progress

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
TOTAL=$(frontmatter_get "$STATE_FILE" "total_tasks" "0")
echo "PROGRESS:$CURRENT/$TOTAL"
```

If CURRENT >= TOTAL: Go to Step 4.

### 3b. Select Model

| Model  | Use For                          |
| ------ | -------------------------------- |
| haiku  | Simple tasks (<3 files)          |
| sonnet | Standard tasks (default)         |
| opus   | Complex (5+ files, architecture) |

### 3c. Dispatch Task Subagent

**CRITICAL: Pass explicit paths to every subagent.**

````claude
Task tool:
  model: [selected-model]
  prompt: |
    Implement Task [N] of [TOTAL].

    ## EXPLICIT PATHS (use these exactly)

    WORKTREE_PATH: [WORKTREE from state]
    STATE_FILE: [STATE_FILE]
    PLAN_FILE: [PLAN from state]

    ## FIRST ACTIONS

    1. Change directory:
       ```bash
       cd "[WORKTREE_PATH]"
       pwd
       ```

    2. Read your task from plan:
       ```bash
       awk '/^### Task [N]:/,/^### Task [N+1]:|^## /' "[PLAN_FILE]"
       ```

    ## IMPLEMENT

    1. Follow TDD: write failing test first
    2. Run tests, verify pass
    3. Commit: `git add -A && git commit -m "feat(scope): description"`

    ## CONSTRAINTS

    - Only implement Task [N]
    - Tests must pass before commit
    - Do not modify STATE_FILE (orchestrator does that)
````

### 3d. Verify Commit

After subagent returns:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
cd "$WORKTREE"

LAST_COMMIT=$(frontmatter_get "$STATE_FILE" "last_commit" "")
CURRENT_HEAD=$(git rev-parse HEAD)

if [[ "$LAST_COMMIT" != "$CURRENT_HEAD" ]]; then
  echo "COMMITTED:$CURRENT_HEAD"
else
  echo "NO_COMMIT"
fi
```

**If NO_COMMIT:** Dispatch fix subagent with error context. Do not attempt manual fix (context pollution).

**If COMMITTED:** Update state:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
NEXT=$((CURRENT + 1))
frontmatter_set "$STATE_FILE" "current_task" "$NEXT"
frontmatter_set "$STATE_FILE" "last_commit" "$(git rev-parse HEAD)"
echo "UPDATED:task $NEXT"
```

Mark task `completed` in TodoWrite.

### 3e. Continue

Return to 3a.

## Step 4: Final Code Review

Mark "Final Code Review" `in_progress`.

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
cd "$WORKTREE"
BASE_SHA=$(frontmatter_get "$STATE_FILE" "base_sha" "")
git diff "$BASE_SHA"..HEAD --stat
```

Dispatch code-reviewer:

```claude
Task tool (dev-workflow:code-reviewer):
  model: sonnet
  prompt: |
    Review changes in worktree.

    WORKTREE_PATH: [WORKTREE]
    PLAN_FILE: [PLAN]
    BASE_SHA: [BASE_SHA]

    First: cd "[WORKTREE_PATH]"
    Then: git diff [BASE_SHA]..HEAD

    Focus: Cross-cutting concerns, consistency.
```

Use `Skill("dev-workflow:receiving-code-review")` to process feedback.

Fix Critical issues before proceeding.

Mark `completed`.

## Step 5: Finish

Mark "Finish Branch" `in_progress`.

Use `Skill("dev-workflow:finishing-a-development-branch")`.

```bash
rm -f "$STATE_FILE"
```

Mark `completed`.

Report:

```text
✓ Plan executed: [TOTAL] tasks
✓ Worktree: [WORKTREE]
✓ Code reviewed
✓ Branch finished

Workflow complete.
```

## Resume Flow

When state file exists with CURRENT > 0:

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

**5. Continue from Step 3** (3a will find next task).

## Error Recovery

```bash
# View state
cat "$STATE_FILE"

# Rollback
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
cd "$WORKTREE"
BASE_SHA=$(frontmatter_get "$STATE_FILE" "base_sha" "")
git reset --hard "$BASE_SHA"
rm "$STATE_FILE"
```

## Red Flags

**Never:**

- Skip Final Code Review
- Proceed with Critical issues unfixed
- Dispatch parallel subagents on overlapping files
- Mark task complete without commit verification
- Use task-indexed commit messages (use conventional commits)
- Attempt manual fix when subagent fails (context pollution)

**If subagent fails:**

1. Check git status for uncommitted changes
2. Dispatch fix subagent with error context
3. If fix subagent fails twice, use Handle Blocker pattern

## Key Principle

**Every subagent receives explicit paths.** No path discovery via `git rev-parse`. The orchestrator knows all paths from state file and passes them in prompts.
