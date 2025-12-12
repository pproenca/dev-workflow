# State File Format Reference

All dev-workflow state is stored in `.claude/dev-workflow-state.local.md` (relative to git repo root).

**Important:** Always use absolute paths when accessing state files. Use the helper functions from `scripts/hook-helpers.sh`:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
STATE_FILE="$(get_state_file)"      # Returns absolute path
HANDOFF_FILE="$(get_handoff_file)"  # Returns absolute path
```

## Format

```markdown
---
workflow: execute-plan | subagent
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

| Field | Required | Description |
|-------|----------|-------------|
| `workflow` | Yes | `execute-plan` or `subagent` |
| `plan` | Yes | Absolute path to plan file |
| `base_sha` | Yes | Commit before workflow started |
| `current_task` | Yes | Task number in progress (0 = not started) |
| `total_tasks` | Yes | Total task count from plan |
| `last_commit` | Yes | HEAD after last completed task |
| `enabled` | Yes | `true` to continue, `false` to pause |

## Reading State

Commands read state using `@` file reference:

```text
Current state: @.claude/dev-workflow-state.local.md
```

### Using Helper Functions (Recommended)

Source `scripts/hook-helpers.sh` for safe frontmatter parsing:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"

# Get absolute path to state file
STATE_FILE="$(get_state_file)"

# frontmatter_get <file> <key> [default]
# - Isolates frontmatter between --- markers (won't match keys in body)
# - Strips quotes from values
# - Returns default if key not found
PLAN=$(frontmatter_get "$STATE_FILE" "plan" "")
CURRENT=$(frontmatter_get "$STATE_FILE" "current_task" "0")
```

## Updating State

### Using Helper Functions (Recommended)

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"

# Get absolute path to state file
STATE_FILE="$(get_state_file)"

# frontmatter_set <file> <key> <value>
# - Uses temp file + mv pattern to prevent corruption
frontmatter_set "$STATE_FILE" "current_task" "$NEXT_TASK"
frontmatter_set "$STATE_FILE" "last_commit" "$(git rev-parse HEAD)"
```

### Multiple Fields (Atomic)

For updating multiple fields atomically, use sed with temp file:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
STATE_FILE="$(get_state_file)"
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
STATE_FILE="$(get_state_file)"

STATE_COMMIT=$(frontmatter_get "$STATE_FILE" "last_commit" "")
CURRENT_HEAD="$(git rev-parse HEAD)"

if [[ "$STATE_COMMIT" != "$CURRENT_HEAD" ]]; then
  echo "New commit detected - task completed"
fi
```

## Worktree Management

Use `scripts/worktree-manager.sh` for worktree and handoff operations:

```bash
# Create worktree + handoff in one call
worktree-manager.sh setup /path/to/plan.md sequential

# Find pending worktree
worktree-manager.sh pending

# Activate with mode and get path
worktree-manager.sh activate subagent

# Update mode only
worktree-manager.sh set-mode /path/to/.worktrees/plan-name sequential

# List/remove worktrees
worktree-manager.sh list
worktree-manager.sh remove plan-name
```

For scripting, source the file to use functions directly:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/worktree-manager.sh"

# Create handoff state
create_handoff_state "$plan_file" "$worktree_path" "sequential"

# Update handoff mode atomically
set_handoff_mode "$worktree_path" "subagent"
```

## Commit Messages

Use conventional commits. Task tracking is in state file, not commits:

```bash
# Good - conventional
git commit -m "feat(auth): implement JWT token generation"
git commit -m "fix(api): handle null response edge case"
git commit -m "test(auth): add token expiration tests"

# Bad - task-based (old format, do not use)
git commit -m "task(3): Implement authentication"
```

## Recovery

If state file is deleted, recreate manually:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/hook-helpers.sh"
STATE_FILE="$(get_state_file)"
mkdir -p "$(dirname "$STATE_FILE")"

cat > "$STATE_FILE" << 'EOF'
---
workflow: execute-plan
plan: /path/to/your/plan.md
base_sha: $(git merge-base HEAD main)
current_task: 3
total_tasks: 5
last_commit: $(git rev-parse HEAD)
enabled: true
---

Recovered state - verify current_task is correct
EOF
```

The plan file and git history remain intact. Only `current_task` needs manual verification.

## Handoff State

For worktree handoffs, use `.claude/pending-handoff.local.md`:

```markdown
---
plan: /absolute/path/to/plan.md
mode: pending | sequential | subagent
---
```

### Modes

| Mode | Description |
|------|-------------|
| `pending` | Worktree created, awaiting execution choice |
| `sequential` | Execute via `/dev-workflow:execute-plan` with checkpoints |
| `subagent` | Execute via `dev-workflow:subagent-driven-development` skill |

### Creating Handoff State

Use `worktree-manager.sh` (see Worktree Management above):

```bash
# Via CLI
worktree-manager.sh setup /path/to/plan.md pending

# Via function
source "${CLAUDE_PLUGIN_ROOT}/scripts/worktree-manager.sh"
create_handoff_state "$plan_file" "$worktree_path" "pending"
```

### Updating Mode

```bash
# Via CLI
worktree-manager.sh set-mode "$worktree_path" sequential

# Via function
set_handoff_mode "$worktree_path" "subagent"
```

The `SessionStart` hook reads handoff state and triggers appropriate resumption.

## Design Principles

1. **Frontmatter only** - No markdown sections for machine state
2. **Git for history** - Commits are conventional, not task-indexed
3. **State file for position** - Current task tracked here, not in commits
4. **Minimal tokens** - ~50 tokens vs ~350+ in verbose format
5. **Atomic updates** - Use temp file + mv pattern
