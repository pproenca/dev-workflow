# State File Format Reference

All dev-workflow state is stored in `.claude/dev-workflow-state.local.md` (relative to worktree root).

## Format

```markdown
---
workflow: execute-plan | subagent
worktree: /absolute/path/to/.worktrees/plan-name-timestamp
plan: /absolute/path/to/plan.md
base_sha: abc123def
current_task: 3
total_tasks: 5
current_group: 2
total_groups: 4
last_commit: def456abc
batch_size: 5
parallel_mode: true
retry_count: 0
failed_tasks: ""
enabled: true
---

Brief context line (optional)
```

## Fields

| Field           | Required | Description                                        |
| --------------- | -------- | -------------------------------------------------- |
| `workflow`      | Yes      | `execute-plan` or `subagent`                       |
| `worktree`      | Yes      | Absolute path to worktree directory                |
| `plan`          | Yes      | Absolute path to plan file                         |
| `base_sha`      | Yes      | Commit before workflow started                     |
| `current_task`  | Yes      | Task number in progress (0 = not started)          |
| `total_tasks`   | Yes      | Total task count from plan                         |
| `current_group` | No       | Current parallel group (1-indexed, for parallel mode) |
| `total_groups`  | No       | Total number of parallel groups                    |
| `last_commit`   | Yes      | HEAD after last completed task                     |
| `batch_size`    | No       | Tasks per orchestrator batch (0 = unbatched)       |
| `parallel_mode` | No       | `true` for parallel execution, `false` for serial  |
| `retry_count`   | No       | Number of retries for current failing task (0-2)   |
| `failed_tasks`  | No       | Comma-separated list of skipped task numbers       |
| `enabled`       | Yes      | `true` to continue, `false` to pause               |

**Note:** Group boundaries are computed by `group_tasks_by_dependency()` based on file overlap analysis.

## Why Explicit Worktree Path

**Critical:** `cd` in bash blocks does not change Claude's working directory. Each bash command runs in isolation.

By storing `worktree` explicitly:

- Subagents receive the path in their prompt
- No reliance on `git rev-parse --show-toplevel`
- State is self-contained and portable
- Debugging is easier (just read the state file)

## Reading State

Use helper functions from `scripts/hook-helpers.sh`:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
STATE_FILE="/path/to/state.local.md"  # Known path, not discovered

# frontmatter_get <file> <key> [default]
# - Isolates frontmatter between --- markers
# - Strips quotes from values
# - Returns default if key not found
WORKTREE=$(frontmatter_get "$STATE_FILE" "worktree" "")
PLAN=$(frontmatter_get "$STATE_FILE" "plan" "")
CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
```

## Creating State

### Using Helper Function (Recommended)

Use `setup_worktree_with_state()` from `scripts/worktree-manager.sh`:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/worktree-manager.sh"
WORKTREE_PATH="$(setup_worktree_with_state "$PLAN_FILE" "subagent")"
STATE_FILE="${WORKTREE_PATH}/.claude/dev-workflow-state.local.md"
```

### Manual Creation

```bash
WORKTREE_PATH="/absolute/path/to/worktree"
PLAN_ABS="/absolute/path/to/plan.md"
STATE_FILE="${WORKTREE_PATH}/.claude/dev-workflow-state.local.md"
TOTAL_TASKS=$(grep -c "^### Task [0-9]\+:" "$PLAN_ABS")

mkdir -p "${WORKTREE_PATH}/.claude"
cat > "$STATE_FILE" << EOF
---
workflow: subagent
worktree: $WORKTREE_PATH
plan: $PLAN_ABS
base_sha: $(git rev-parse HEAD)
current_task: 0
total_tasks: $TOTAL_TASKS
last_commit: $(git rev-parse HEAD)
batch_size: 5
enabled: true
---
EOF
```

## Updating State

### Single Field

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"

# frontmatter_set <file> <key> <value>
# - Uses temp file + mv pattern to prevent corruption
frontmatter_set "$STATE_FILE" "current_task" "$NEXT_TASK"
frontmatter_set "$STATE_FILE" "last_commit" "$(git rev-parse HEAD)"
```

### Multiple Fields (Atomic)

For updating multiple fields atomically, use sed with temp file:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
STATE_FILE="[path]"
TEMP="${STATE_FILE}.tmp.$$"

sed -e "s/^current_task: .*/current_task: $NEXT_TASK/" \
    -e "s/^last_commit: .*/last_commit: $(git rev-parse HEAD)/" \
    "$STATE_FILE" > "$TEMP"
mv "$TEMP" "$STATE_FILE"
```

## Progress Verification

Task completion is verified by comparing `last_commit` to current HEAD:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
STATE_COMMIT=$(frontmatter_get "$STATE_FILE" "last_commit" "")
CURRENT_HEAD="$(git rev-parse HEAD)"

if [[ "$STATE_COMMIT" != "$CURRENT_HEAD" ]]; then
  echo "New commit detected - task completed"
fi
```

## Worktree Management

Use `scripts/worktree-manager.sh` for worktree operations:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/worktree-manager.sh"

# Create worktree + state file (preferred)
WORKTREE_PATH="$(setup_worktree_with_state "$PLAN_FILE" "execute-plan")"

# Check if in main repo
is_main_repo && echo "In main repo" || echo "In worktree"

# List worktrees
list_worktrees

# Remove worktree
remove_worktree "plan-name-timestamp"
```

## Commit Messages

Use conventional commits. Task tracking is in state file, not commits:

```bash
# Good - conventional
git commit -m "feat(auth): implement JWT token generation"
git commit -m "fix(api): handle null response edge case"
git commit -m "test(auth): add token expiration tests"

# Bad - task-based (do not use)
git commit -m "task(3): Implement authentication"
```

## Recovery

If state file is deleted, recreate manually:

```bash
STATE_FILE="[worktree]/.claude/dev-workflow-state.local.md"
mkdir -p "$(dirname "$STATE_FILE")"

cat > "$STATE_FILE" << 'EOF'
---
workflow: execute-plan
worktree: /path/to/worktree
plan: /path/to/your/plan.md
base_sha: [git merge-base HEAD main]
current_task: 3
total_tasks: 5
last_commit: [git rev-parse HEAD]
batch_size: 5
parallel_mode: true
retry_count: 0
failed_tasks: ""
enabled: true
---

Recovered state - verify current_task is correct
EOF
```

The plan file and git history remain intact. Only `current_task` needs manual verification.

## Design Principles

1. **Explicit paths** - Worktree path stored in state, passed to subagents
2. **Frontmatter only** - No markdown sections for machine state
3. **Git for history** - Commits are conventional, not task-indexed
4. **State file for position** - Current task tracked here, not in commits
5. **Minimal tokens** - ~50 tokens vs ~350+ in verbose format
6. **Atomic updates** - Use temp file + mv pattern

## Progress Log (Anthropic Pattern)

Location: `.claude/dev-workflow-progress.log`

The progress log provides session continuity and enables quick context restoration on resume.

### Format

```
[2024-01-15T10:30:00Z] PLAN: Created plan with 12 tasks, 4 parallel groups
[2024-01-15T10:31:00Z] GROUP_START: Group 1 (tasks 1-4, independent files)
[2024-01-15T10:32:00Z] TASK_COMPLETE: Task 1 - commit:abc123 - 8 tool calls
[2024-01-15T10:32:30Z] TASK_COMPLETE: Task 2 - commit:def456 - 12 tool calls
[2024-01-15T10:33:00Z] TASK_COMPLETE: Task 3 - commit:ghi789 - 6 tool calls
[2024-01-15T10:33:30Z] TASK_COMPLETE: Task 4 - commit:jkl012 - 10 tool calls
[2024-01-15T10:33:35Z] GROUP_COMPLETE: Group 1 - 4/4 tasks, 36 total tool calls
[2024-01-15T10:33:40Z] PHASE_SUMMARY: Implemented auth module (tasks 1-4), all tests pass
[2024-01-15T10:34:00Z] GROUP_START: Group 2 (tasks 5-8, API endpoints)
```

### Event Types

| Event           | When Logged                          |
| --------------- | ------------------------------------ |
| `PLAN`          | Plan created or loaded               |
| `GROUP_START`   | Parallel group execution begins      |
| `TASK_COMPLETE` | Individual task completed            |
| `GROUP_COMPLETE`| All tasks in group finished          |
| `PHASE_SUMMARY` | Summary before next phase (context)  |
| `ERROR`         | Error occurred (for recovery)        |
| `RESUME`        | Session resumed from checkpoint      |

### Helper Functions

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"

# Log an event
log_progress "TASK_COMPLETE" "Task 3 - commit:abc123 - 8 tool calls"

# Get recent progress (for resume)
get_recent_progress 10

# Get last phase summary (for context)
get_last_phase_summary
```

## Task Outputs (Lightweight Reference Pattern)

Location: `.claude/task-outputs/task-{N}.md`

Subagents write output to filesystem instead of returning through orchestrator. This prevents context bloat.

### Pattern

```
Subagent executes task
    ↓
Writes output to: .claude/task-outputs/task-3.md
    ↓
Returns lightweight reference:
    { "task": 3, "commit": "abc123", "status": "complete" }
    ↓
Orchestrator reads output file ONLY if synthesis needed
```

### Output File Format

```markdown
# Task 3: Implement user authentication

## Status: complete
## Commit: abc123def
## Tool Calls: 8

## Files Changed
- src/auth/login.ts (created)
- src/auth/types.ts (modified)
- tests/auth/login.test.ts (created)

## Summary
Implemented JWT-based login endpoint with password hashing.
All tests pass.

## Notes
Used bcrypt for password hashing per security requirements.
```

### Helper Functions

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"

# Get output file path
OUTPUT_FILE=$(create_task_output_path 3)
echo "Writing to: $OUTPUT_FILE"
```

## Parallel Execution Groups

Tasks are grouped by file dependencies for parallel execution.

### Grouping Rules

1. Tasks with **no file overlap** → Can execute in parallel (same group)
2. Tasks with **file overlap** → Must execute serially (different groups)
3. Maximum **5 tasks per group** (Anthropic pattern)

### Helper Functions

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"

# Get files touched by a task
get_task_files "$PLAN_FILE" 3

# Check if two tasks have dependency
tasks_overlap "$PLAN_FILE" 3 4  # Returns 0 if overlap, 1 if no overlap

# Group all tasks by dependency
# Output: group1:1,2,3|group2:4,5|group3:6,7,8
group_tasks_by_dependency "$PLAN_FILE" "$TOTAL_TASKS" 5
```
