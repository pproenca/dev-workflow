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

**Parallel workflows:** Multiple workflows can run simultaneously in separate worktrees (different terminal sessions).
**Within-session execution:** Tasks execute sequentially within each session. True parallelization requires multiple terminal sessions, each in its own worktree.

## Prerequisites

Before this skill loads, you should have received:

- `WORKTREE_PATH` - absolute path to the worktree
- `STATE_FILE` - absolute path to state file
- `PLAN_FILE` - absolute path to plan (also in state file)

**If you don't have WORKTREE_PATH, STATE_FILE, or PLAN_FILE:** Stop and report error. The caller must provide explicit paths.

**Batch mode detection:** Check `batch_size` in state file. If present and > 0, this is batched execution. Calculate your batch boundary as: `batch_end = min(current_task + batch_size, total_tasks)`. Execute until batch_end, then STOP. Do NOT proceed to Final Code Review (caller handles that).

**Unbatched mode:** If `batch_size` is 0 or missing, execute all tasks, then proceed to Final Code Review.

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

WORKTREE_PATH=$(frontmatter_get "$STATE_FILE" "worktree" "")
PLAN_FILE=$(frontmatter_get "$STATE_FILE" "plan" "")
CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
TOTAL=$(frontmatter_get "$STATE_FILE" "total_tasks" "0")
BASE_SHA=$(frontmatter_get "$STATE_FILE" "base_sha" "")

echo "WORKTREE_PATH:$WORKTREE_PATH"
echo "PLAN_FILE:$PLAN_FILE"
echo "PROGRESS:$CURRENT/$TOTAL"
```

**Store these values - you will pass them to every subagent as WORKTREE_PATH, STATE_FILE, PLAN_FILE.**

## Step 1: Setup TodoWrite

Extract tasks and create TodoWrite items:

```bash
grep -E "^### Task [0-9]+:" "$PLAN_FILE" | sed 's/^### Task \([0-9]*\): \(.*\)/Task \1: \2/'
```

Use TodoWrite for: all tasks + "Final Code Review" + "Finish Branch".

## Step 2: Analyze Dependencies

```bash
awk '/^### Task [0-9]+:/,/^### Task [0-9]+:|^## /' "$PLAN_FILE" | \
  grep -E '(Create|Modify|Test):' | \
  grep -oE '`[^`]+`' | tr -d '`' | sort -u
```

Build dependency model:

- File overlap → Must execute sequentially (even across worktrees)
- No overlap → Can run in parallel worktrees (separate terminal sessions)

**To parallelize independent tasks:** Create multiple worktrees and run separate `/dev-workflow:execute-plan` sessions in each. Tasks with no file overlap can safely run simultaneously in different worktrees.

## Step 3: Execute Tasks

### 3a. Check Progress

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
TOTAL=$(frontmatter_get "$STATE_FILE" "total_tasks" "0")
BATCH_SIZE=$(frontmatter_get "$STATE_FILE" "batch_size" "0")

# Calculate batch boundary (0 = unbatched mode, execute all)
if [[ "$BATCH_SIZE" -gt 0 ]]; then
  BATCH_END=$((CURRENT + BATCH_SIZE))
  [[ $BATCH_END -gt $TOTAL ]] && BATCH_END=$TOTAL
  IS_BATCHED="true"
else
  BATCH_END=$TOTAL
  IS_BATCHED="false"
fi
echo "PROGRESS:$CURRENT/$BATCH_END (total: $TOTAL, batched: $IS_BATCHED)"
```

**If CURRENT >= BATCH_END:**
- If IS_BATCHED="true" and BATCH_END < TOTAL: Report "Batch complete ($CURRENT tasks done)" and **STOP** (caller spawns next batch)
- Otherwise: Go to Step 4 (Final Code Review)

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
cd "$WORKTREE_PATH"

LAST_COMMIT=$(frontmatter_get "$STATE_FILE" "last_commit" "")
CURRENT_HEAD=$(git rev-parse HEAD)

if [[ "$LAST_COMMIT" != "$CURRENT_HEAD" ]]; then
  echo "COMMITTED:$CURRENT_HEAD"
else
  echo "NO_COMMIT"
fi
```

**If NO_COMMIT:**

Get error context:
```bash
cd "$WORKTREE_PATH"
echo "=== Git Status ==="
git status --short
echo "=== Uncommitted Changes ==="
git diff --stat 2>/dev/null || true
```

Dispatch fix subagent (escalate to opus):

```claude
Task tool:
  model: opus
  prompt: |
    Task [N] failed to complete with commit.

    ## PATHS
    WORKTREE_PATH: [WORKTREE]
    STATE_FILE: [STATE_FILE]
    PLAN_FILE: [PLAN]

    ## ERROR CONTEXT
    [paste git status and diff output]

    ## INSTRUCTIONS
    1. cd "[WORKTREE_PATH]"
    2. Diagnose the issue (test failures, incomplete implementation)
    3. Fix the problem
    4. Run tests: [test command]
    5. Commit: git add -A && git commit -m "fix: [description]"

    CONSTRAINT: You MUST commit before returning.
```

If fix subagent also returns NO_COMMIT, use AskUserQuestion:

```claude
AskUserQuestion:
  header: "Blocker"
  question: "Task [N] failed twice. What should we do?"
  multiSelect: false
  options:
    - label: "Skip"
      description: "Mark incomplete, continue to next task"
    - label: "Retry manually"
      description: "Provide guidance to help resolve"
    - label: "Abort"
      description: "Stop workflow, preserve state for later"
```

- If "Skip": Increment current_task, mark task as skipped in TodoWrite, continue to 3a
- If "Retry manually": Wait for user guidance, then dispatch another fix subagent
- If "Abort": STOP workflow

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

**Skip if batch mode:** If you're in batched mode (batch_size > 0 in state), report "Batch complete" and **STOP**. Caller handles Final Code Review after all batches complete.

Mark "Final Code Review" `in_progress`.

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
cd "$WORKTREE_PATH"
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

**Skip if batch mode:** Caller handles Finish after all batches.

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
PLAN_FILE="$(frontmatter_get "$STATE_FILE" "plan" "")"
CURRENT="$(frontmatter_get "$STATE_FILE" "current_task" "0")"
TOTAL="$(frontmatter_get "$STATE_FILE" "total_tasks" "0")"
ENABLED="$(frontmatter_get "$STATE_FILE" "enabled" "true")"
```

**2. Verify enabled:**

If `enabled: false`, ask user if they want to continue.

**3. Verify plan exists:**

```bash
test -f "$PLAN_FILE" || echo "Plan file missing: $PLAN_FILE"
```

**4. Rebuild TodoWrite** based on current_task position.

**5. Continue from Step 3** (3a will find next task).

## Error Recovery

```bash
# View state
cat "$STATE_FILE"

# Rollback
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
cd "$WORKTREE_PATH"
BASE_SHA=$(frontmatter_get "$STATE_FILE" "base_sha" "")
git reset --hard "$BASE_SHA"
rm "$STATE_FILE"
```

## Red Flags

**Never:**

- Skip Final Code Review
- Proceed with Critical issues unfixed
- Mark task complete without commit verification
- Use task-indexed commit messages (use conventional commits)
- Attempt manual fix when subagent fails (dispatch fix subagent instead)

**If subagent fails:**

1. Check git status for uncommitted changes
2. Dispatch fix subagent (opus model) with error context
3. If fix subagent also fails, use AskUserQuestion to get user decision (Skip/Retry/Abort)

## Key Principle

**Every subagent receives explicit paths.** No path discovery via `git rev-parse`. The orchestrator knows all paths from state file and passes them in prompts.
