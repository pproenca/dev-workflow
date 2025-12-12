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
last_commit: def456abc
enabled: true
---

Brief context line (optional)
```

## Fields

| Field          | Required | Description                               |
| -------------- | -------- | ----------------------------------------- |
| `workflow`     | Yes      | `execute-plan` or `subagent`              |
| `worktree`     | Yes      | Absolute path to worktree directory       |
| `plan`         | Yes      | Absolute path to plan file                |
| `base_sha`     | Yes      | Commit before workflow started            |
| `current_task` | Yes      | Task number in progress (0 = not started) |
| `total_tasks`  | Yes      | Total task count from plan                |
| `last_commit`  | Yes      | HEAD after last completed task            |
| `enabled`      | Yes      | `true` to continue, `false` to pause      |

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
