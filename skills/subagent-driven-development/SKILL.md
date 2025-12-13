---
name: subagent-driven-development
description: Execute plan using Anthropic's proven multi-agent pattern. Dispatches 3-5 subagents in parallel per group, uses lightweight references, logs progress. Use when asked to "use subagents", "execute in this session", "parallel tasks", or after `/dev-workflow:write-plan` when choosing subagent execution.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, TodoWrite, Task, Skill, AskUserQuestion
---

# Subagent-Driven Development

Execute plan using Anthropic's proven multi-agent orchestrator-worker pattern:

- **Lead Agent (You, Opus)**: Orchestrates, plans, spawns subagents, synthesizes results
- **Subagents (Sonnet)**: Execute specific tasks with clear boundaries, write output to filesystem

Reference: [Anthropic Multi-Agent Research System](https://www.anthropic.com/engineering/multi-agent-research-system)

## Execution Behavior

**This is a continuous workflow. Do not stop between steps.**

After loading this skill, execute all steps until "Workflow complete". Only permitted stops:

1. AskUserQuestion (wait for response, then continue)
2. Blocker requiring user input
3. Final completion report

**Critical:** After ANY tool call completes, immediately make the next tool call. Do not narrate between tool calls.

## Key Patterns

| Pattern | Implementation |
|---------|----------------|
| **Parallel dispatch** | 3-5 subagents per group, dispatched in SINGLE Task call |
| **Lightweight references** | Subagents write to filesystem, return commit SHA only |
| **Progress log** | All events logged to `.claude/dev-workflow-progress.log` |
| **Phase summaries** | Summarize completed work before next group |
| **Effort scaling** | Simple: 1 subagent, Complex: 3-5 subagents |

## Prerequisites

Before this skill loads, you should have received:

- `WORKTREE_PATH` - absolute path to the worktree
- `STATE_FILE` - absolute path to state file

**If you don't have WORKTREE_PATH or STATE_FILE:** Stop and report error.

## Step 0: Establish Context

**FIRST**, change to worktree and read state:

```bash
cd "[WORKTREE_PATH]"
pwd

source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
STATE_FILE="[STATE_FILE from your prompt]"

WORKTREE_PATH=$(frontmatter_get "$STATE_FILE" "worktree" "")
PLAN_FILE=$(frontmatter_get "$STATE_FILE" "plan" "")
CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
TOTAL=$(frontmatter_get "$STATE_FILE" "total_tasks" "0")
PARALLEL_MODE=$(frontmatter_get "$STATE_FILE" "parallel_mode" "true")
BASE_SHA=$(frontmatter_get "$STATE_FILE" "base_sha" "")

echo "WORKTREE_PATH:$WORKTREE_PATH"
echo "PLAN_FILE:$PLAN_FILE"
echo "PROGRESS:$CURRENT/$TOTAL"
echo "PARALLEL_MODE:$PARALLEL_MODE"

# Check for resume - read recent progress
get_recent_progress 5
```

**If CURRENT > 0:** Log resume event:
```bash
log_progress "RESUME" "Resuming from task $((CURRENT+1)) of $TOTAL"
```

## Step 1: Analyze Dependencies & Create Groups

**Compute parallel groups based on file overlap:**

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"

# Group tasks (max 5 per group per Anthropic pattern)
GROUPS=$(group_tasks_by_dependency "$PLAN_FILE" "$TOTAL" 5)
TOTAL_GROUPS=$(echo "$GROUPS" | tr '|' '\n' | wc -l | tr -d ' ')

echo "GROUPS: $GROUPS"
echo "TOTAL_GROUPS: $TOTAL_GROUPS"

# Log plan analysis
log_progress "PLAN" "Analyzed $TOTAL tasks into $TOTAL_GROUPS parallel groups"
```

**Parse groups for execution:**
- Format: `group1:1,2,3|group2:4,5|group3:6,7,8,9`
- Tasks within a group have NO file overlap → execute in parallel
- Groups execute serially (group 1 completes before group 2)

## Step 2: Setup TodoWrite

**REPLACE any existing todos with current state:**

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")

# Get task titles
grep -E "^### Task [0-9]+:" "$PLAN_FILE" | sed 's/^### Task \([0-9]*\): \(.*\)/Task \1: \2/'
```

**Single TodoWrite call that REPLACES all items:**
- Tasks 1 to CURRENT: `completed`
- Tasks CURRENT+1 to TOTAL: `pending`
- Add "Final Code Review" + "Finish Branch" as `pending`

**Critical:** Subagents do NOT use TodoWrite. Only this orchestrator updates status.

## Step 3: Execute Groups

### 3a. Find Current Group

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
GROUPS=$(group_tasks_by_dependency "$PLAN_FILE" "$TOTAL" 5)

# Find which group contains next task
NEXT_TASK=$((CURRENT + 1))
CURRENT_GROUP=""
CURRENT_GROUP_NUM=0

IFS='|' read -ra GROUP_ARRAY <<< "$GROUPS"
for i in "${!GROUP_ARRAY[@]}"; do
  GROUP="${GROUP_ARRAY[$i]}"
  TASKS="${GROUP#*:}"

  # Check if NEXT_TASK is in this group
  if echo ",$TASKS," | grep -q ",$NEXT_TASK,"; then
    CURRENT_GROUP="$TASKS"
    CURRENT_GROUP_NUM=$((i + 1))
    break
  fi
done

echo "CURRENT_GROUP_NUM: $CURRENT_GROUP_NUM"
echo "CURRENT_GROUP_TASKS: $CURRENT_GROUP"
```

**If no current group found:** All tasks complete, go to Step 4 (Final Code Review).

### 3b. Log Group Start

```bash
log_progress "GROUP_START" "Group $CURRENT_GROUP_NUM (tasks $CURRENT_GROUP)"
```

### 3c. Extract Task Sections for Group

**Extract ALL task sections for this group BEFORE dispatching:**

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"

# Parse task numbers from group
IFS=',' read -ra TASK_NUMS <<< "$CURRENT_GROUP"

for TASK_NUM in "${TASK_NUMS[@]}"; do
  NEXT_TASK=$((TASK_NUM + 1))
  TASK_SECTION=$(awk "/^### Task ${TASK_NUM}:/,/^### Task ${NEXT_TASK}:|^## /" "$PLAN_FILE" | head -n -1)

  echo "=== TASK $TASK_NUM (${#TASK_SECTION} bytes) ==="
  echo "$TASK_SECTION"
  echo ""
done
```

### 3d. Dispatch Group in Parallel

**CRITICAL: Dispatch ALL tasks in the group in a SINGLE message with multiple Task tool calls.**

For each task in the group, dispatch a subagent:

````claude
Task tool:
  model: sonnet
  prompt: |
    Implement Task [TASK_NUM] of [TOTAL].

    ## WORKTREE
    [WORKTREE_PATH]

    ## OUTPUT FILE
    Write your completion report to: .claude/task-outputs/task-[TASK_NUM].md

    ## YOUR TASK
    [TASK_SECTION content]

    ## INSTRUCTIONS
    1. cd "[WORKTREE_PATH]"
    2. Follow TDD: write failing test, implement, verify pass
    3. Commit: git add -A && git commit -m "feat(scope): description"
    4. Write output report to OUTPUT FILE with this EXACT format:

       If successful:
       ```
       ## Status: complete
       ## Commit: [full 40-char SHA]
       ## Files Changed
       - path/to/file.py (created)
       - path/to/other.py (modified)
       ## Summary
       Brief description of what was implemented.
       ```

       If failed:
       ```
       ## Status: failed
       ## Error
       [Error message and context for debugging]
       ## Partial Progress
       [Any files created/modified before failure]
       ```

    ## CONSTRAINTS
    - Only implement this task
    - Tests must pass before commit
    - Do NOT use TodoWrite (orchestrator handles)
    - Write output to filesystem, return only: "TASK [N] COMPLETE: [commit_sha]" or "TASK [N] FAILED: [reason]"

    ## EFFORT BUDGET
    Simple task: 3-10 tool calls
    Standard task: 10-15 tool calls
    Complex task: 15-25 tool calls
````

**Parallel dispatch example for group with tasks 1,2,3:**

```
Send SINGLE message with THREE Task tool calls:
- Task tool for Task 1 (sonnet)
- Task tool for Task 2 (sonnet)
- Task tool for Task 3 (sonnet)

All three execute concurrently. Wait for all to complete.
```

### 3e. Process Group Results

After ALL subagents in the group return:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
cd "$WORKTREE_PATH"

# Check each task's output file
IFS=',' read -ra TASK_NUMS <<< "$CURRENT_GROUP"
COMPLETED=0
FAILED=0

for TASK_NUM in "${TASK_NUMS[@]}"; do
  OUTPUT_FILE=".claude/task-outputs/task-${TASK_NUM}.md"

  if [[ -f "$OUTPUT_FILE" ]]; then
    STATUS=$(grep "^## Status:" "$OUTPUT_FILE" | sed 's/## Status: //')
    COMMIT=$(grep "^## Commit:" "$OUTPUT_FILE" | sed 's/## Commit: //')

    if [[ "$STATUS" == "complete" ]]; then
      log_progress "TASK_COMPLETE" "Task $TASK_NUM - commit:${COMMIT:0:7}"
      ((COMPLETED++))
    else
      log_progress "ERROR" "Task $TASK_NUM failed"
      ((FAILED++))
    fi
  else
    log_progress "ERROR" "Task $TASK_NUM - no output file"
    ((FAILED++))
  fi
done

echo "GROUP_RESULTS: $COMPLETED completed, $FAILED failed"
```

**If any task failed:** Handle with retry logic (see Error Recovery section).

**If all succeeded:** Update state and TodoWrite:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"

# Count completed tasks
IFS=',' read -ra TASK_NUMS <<< "$CURRENT_GROUP"
NEW_CURRENT=$((CURRENT + ${#TASK_NUMS[@]}))

frontmatter_set "$STATE_FILE" "current_task" "$NEW_CURRENT"
frontmatter_set "$STATE_FILE" "last_commit" "$(git rev-parse HEAD)"

log_progress "GROUP_COMPLETE" "Group $CURRENT_GROUP_NUM - ${#TASK_NUMS[@]} tasks"

echo "UPDATED: current_task=$NEW_CURRENT"
```

Mark all group tasks as `completed` in TodoWrite.

### 3f. Phase Summary

**Before proceeding to next group, summarize this phase:**

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"

# Generate summary of what was done
git log --oneline "$BASE_SHA"..HEAD | head -5

# Log phase summary
log_progress "PHASE_SUMMARY" "Group $CURRENT_GROUP_NUM complete: [brief description of what was implemented]"
```

Write a brief summary to the progress log describing what was accomplished.

### 3g. Continue to Next Group

Return to Step 3a to find and execute the next group.

## Step 4: Final Code Review

**After all groups complete:**

Mark "Final Code Review" `in_progress` in TodoWrite.

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
    Review all changes in worktree.

    WORKTREE_PATH: [WORKTREE_PATH]
    BASE_SHA: [BASE_SHA]

    First: cd "[WORKTREE_PATH]"
    Then: git diff [BASE_SHA]..HEAD

    Focus: Cross-cutting concerns, consistency across all tasks.
```

Use `Skill("dev-workflow:receiving-code-review")` to process feedback.

Fix Critical issues before proceeding.

Mark `completed` in TodoWrite.

```bash
log_progress "PHASE_SUMMARY" "Code review complete, all issues addressed"
```

## Step 5: Finish

Mark "Finish Branch" `in_progress` in TodoWrite.

Use `Skill("dev-workflow:finishing-a-development-branch")`.

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
log_progress "PHASE_SUMMARY" "Workflow complete: $TOTAL tasks executed in $TOTAL_GROUPS groups"
rm -f "$STATE_FILE"
```

Mark `completed` in TodoWrite.

Report:

```text
✓ Plan executed: [TOTAL] tasks in [TOTAL_GROUPS] parallel groups
✓ Worktree: [WORKTREE_PATH]
✓ Code reviewed
✓ Branch finished

Workflow complete.
```

## Error Recovery

### Task Failed in Group

If a task fails (no commit, test failure):

1. **Check output file** for error details:
```bash
cat ".claude/task-outputs/task-${TASK_NUM}.md"
```

2. **Dispatch fix subagent** (escalate to opus):

```claude
Task tool:
  model: opus
  prompt: |
    Task [TASK_NUM] failed. Fix and complete it.

    WORKTREE_PATH: [WORKTREE_PATH]
    OUTPUT_FILE: .claude/task-outputs/task-[TASK_NUM].md

    ## ORIGINAL TASK
    [TASK_SECTION]

    ## ERROR CONTEXT
    [Content from output file or git status]

    ## INSTRUCTIONS
    1. cd "[WORKTREE_PATH]"
    2. Diagnose and fix the issue
    3. Run tests, verify pass
    4. Commit with fix
    5. Update the output file with success status

    CONSTRAINT: Must commit before returning.
```

3. **If fix fails twice**, use AskUserQuestion:

```claude
AskUserQuestion:
  header: "Blocker"
  question: "Task [N] failed twice. What should we do?"
  multiSelect: false
  options:
    - label: "Skip"
      description: "Mark incomplete, continue"
    - label: "Retry"
      description: "Provide guidance"
    - label: "Abort"
      description: "Stop workflow"
```

### Resume from Checkpoint

When resuming (CURRENT > 0):

1. Read progress log: `get_recent_progress 10`
2. Read last phase summary: `get_last_phase_summary`
3. Continue from current group (Step 3a)

## Red Flags

**Never:**

- Dispatch tasks serially when they can be parallel
- Skip phase summaries between groups
- Let subagents use TodoWrite
- Return full output through orchestrator (use filesystem)
- Skip Final Code Review
- Proceed with Critical issues unfixed

## Key Principles

1. **Parallel first**: Group independent tasks, dispatch together
2. **Lightweight references**: Subagents write to filesystem, return SHA only
3. **Progress logging**: Every event logged for resume capability
4. **Phase summaries**: Summarize before proceeding (context for next phase)
5. **Effort scaling**: Simple=3-10 calls, Standard=10-15, Complex=15-25
