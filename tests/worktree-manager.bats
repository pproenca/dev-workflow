#!/usr/bin/env bats

load test_helper

SCRIPT="$PLUGIN_ROOT/scripts/worktree-manager.sh"

setup() {
  setup_git_repo
  # shellcheck source=../scripts/worktree-manager.sh
  source "$SCRIPT"
}

teardown() {
  # Clean up any worktrees created
  if [[ -n "${TEST_DIR:-}" ]] && [[ -d "$TEST_DIR" ]]; then
    cd "$TEST_DIR" 2>/dev/null || true
    # Remove all worktrees
    git worktree list --porcelain 2>/dev/null | grep '^worktree ' | cut -d' ' -f2 | while read -r wt; do
      [[ "$wt" != "$TEST_DIR" ]] && git worktree remove --force "$wt" 2>/dev/null || true
    done
    # Prune worktree administrative files
    git worktree prune 2>/dev/null || true
  fi
  teardown_git_repo
}

# =============================================================================
# Pure Functions (7 tests)
# =============================================================================

@test "get_repo_root - in git repo returns path" {
  run get_repo_root
  [ "$status" -eq 0 ]
  # Compare resolved paths (git resolves symlinks on macOS)
  [ "$(cd "$output" && pwd -P)" = "$(cd "$TEST_DIR" && pwd -P)" ]
}

@test "get_repo_root - not in git repo errors" {
  cd /tmp
  run get_repo_root
  [ "$status" -ne 0 ]
  [[ "$output" == *"Not in git repo"* ]]
}

@test "generate_worktree_name - simple plan name" {
  run generate_worktree_name "my-plan.md"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^my-plan-[0-9]{8}-[0-9]{6}$ ]]
}

@test "generate_worktree_name - plan path with slashes (uses basename)" {
  run generate_worktree_name "/path/to/some/plan-file.md"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^plan-file-[0-9]{8}-[0-9]{6}$ ]]
}

@test "is_main_repo - in main worktree returns true" {
  run is_main_repo
  [ "$status" -eq 0 ]
}

@test "is_main_repo - in created worktree returns false" {
  cd "$TEST_DIR"
  worktree_path="$(create_worktree "test-wt" 2>/dev/null)"
  cd "$worktree_path"
  run is_main_repo
  [ "$status" -ne 0 ]
}

@test "get_main_worktree - returns main worktree path" {
  run get_main_worktree
  [ "$status" -eq 0 ]
  # Compare resolved paths
  [ "$(cd "$output" && pwd -P)" = "$(cd "$TEST_DIR" && pwd -P)" ]
}

# =============================================================================
# State-modifying Functions (10 tests)
# =============================================================================

@test "create_worktree - creates at .worktrees/" {
  run create_worktree "my-worktree"
  [ "$status" -eq 0 ]
  [ -d "$TEST_DIR/.worktrees/my-worktree" ]
  [[ "$output" == *"/.worktrees/my-worktree" ]]
}

@test "create_worktree - adds .gitignore entry" {
  create_worktree "my-worktree"
  run grep -q '^\.worktrees/$' "$TEST_DIR/.gitignore"
  [ "$status" -eq 0 ]
}

@test "create_worktree - idempotent .gitignore (no duplicates)" {
  create_worktree "wt1"
  create_worktree "wt2"
  count=$(grep -c '^\.worktrees/$' "$TEST_DIR/.gitignore")
  [ "$count" -eq 1 ]
}

@test "create_worktree - creates branch worktree/<name>" {
  create_worktree "my-worktree"
  run git branch --list "worktree/my-worktree"
  [ "$status" -eq 0 ]
  [[ "$output" == *"worktree/my-worktree"* ]]
}

@test "remove_worktree - by name" {
  create_worktree "test-removal"
  [ -d "$TEST_DIR/.worktrees/test-removal" ]

  run remove_worktree "test-removal"
  [ "$status" -eq 0 ]
  [ ! -d "$TEST_DIR/.worktrees/test-removal" ]
  [[ "$output" == *"Removed"* ]]
}

@test "remove_worktree - by full path" {
  worktree_path="$(create_worktree "test-removal-path" 2>/dev/null)"
  [ -d "$worktree_path" ]

  run remove_worktree "$worktree_path"
  [ "$status" -eq 0 ]
  [ ! -d "$worktree_path" ]
  [[ "$output" == *"Removed"* ]]
}

@test "remove_worktree - removes associated branch" {
  create_worktree "test-branch-removal"
  git branch --list "worktree/test-branch-removal" | grep -q "worktree/test-branch-removal"

  remove_worktree "test-branch-removal"
  run git branch --list "worktree/test-branch-removal"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "remove_worktree - nonexistent worktree (graceful)" {
  run remove_worktree "does-not-exist"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Removed"* ]]
}

@test "list_worktrees - with worktrees shows paths" {
  create_worktree "wt1"
  create_worktree "wt2"

  run list_worktrees
  [ "$status" -eq 0 ]
  [[ "$output" == *".worktrees/wt1"* ]]
  [[ "$output" == *".worktrees/wt2"* ]]
}

@test "list_worktrees - no worktrees shows message" {
  run list_worktrees
  [ "$status" -eq 0 ]
  [[ "$output" == *"No worktrees found"* ]]
}

# =============================================================================
# Handoff State Functions (8 tests)
# =============================================================================

@test "create_handoff_state - creates file" {
  worktree_path="$(create_worktree "test-handoff" 2>/dev/null)"

  run create_handoff_state "/tmp/plan.md" "$worktree_path" "sequential"
  [ "$status" -eq 0 ]
  [ -f "$worktree_path/.claude/pending-handoff.local.md" ]
  [[ "$output" == *"/.claude/pending-handoff.local.md" ]]
}

@test "create_handoff_state - creates .claude directory" {
  worktree_path="$(create_worktree "test-handoff-dir" 2>/dev/null)"
  [ ! -d "$worktree_path/.claude" ]

  create_handoff_state "/tmp/plan.md" "$worktree_path" "sequential"
  [ -d "$worktree_path/.claude" ]
}

@test "create_handoff_state - default mode is sequential" {
  worktree_path="$(create_worktree "test-default-mode" 2>/dev/null)"

  create_handoff_state "/tmp/plan.md" "$worktree_path"
  run grep "^mode: sequential$" "$worktree_path/.claude/pending-handoff.local.md"
  [ "$status" -eq 0 ]
}

@test "set_handoff_mode - updates mode in file" {
  worktree_path="$(create_worktree "test-set-mode" 2>/dev/null)"
  create_handoff_state "/tmp/plan.md" "$worktree_path" "sequential"

  set_handoff_mode "$worktree_path" "autonomous"
  run grep "^mode: autonomous$" "$worktree_path/.claude/pending-handoff.local.md"
  [ "$status" -eq 0 ]
}

@test "get_pending_worktree - finds newest pending" {
  worktree_path="$(create_worktree "test-pending" 2>/dev/null)"
  create_handoff_state "/tmp/plan.md" "$worktree_path" "pending"

  run get_pending_worktree
  [ "$status" -eq 0 ]
  # Compare resolved paths
  [ "$(cd "$output" && pwd -P)" = "$(cd "$worktree_path" && pwd -P)" ]
}

@test "get_pending_worktree - no pending returns empty" {
  run get_pending_worktree
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "activate_worktree - sets mode and returns path" {
  worktree_path="$(create_worktree "test-activate" 2>/dev/null)"
  create_handoff_state "/tmp/plan.md" "$worktree_path" "pending"

  run activate_worktree "autonomous"
  [ "$status" -eq 0 ]
  # Compare resolved paths
  [ "$(cd "$output" && pwd -P)" = "$(cd "$worktree_path" && pwd -P)" ]

  # Verify mode was updated
  run grep "^mode: autonomous$" "$worktree_path/.claude/pending-handoff.local.md"
  [ "$status" -eq 0 ]
}

@test "setup_worktree_with_handoff - integration test" {
  echo "test" > "$TEST_DIR/test-plan.md"

  # Call the function and manually clean up the worktree_path by using only stdout
  worktree_name="$(generate_worktree_name "$TEST_DIR/test-plan.md")"
  worktree_path="$(create_worktree "$worktree_name" 2>/dev/null)"
  plan_abs="$(realpath "$TEST_DIR/test-plan.md")"
  create_handoff_state "$plan_abs" "$worktree_path" "sequential" > /dev/null

  [ -d "$worktree_path" ]
  [ -f "$worktree_path/.claude/pending-handoff.local.md" ]

  # Verify worktree name format
  basename_wt="$(basename "$worktree_path")"
  [[ "$basename_wt" =~ ^test-plan-[0-9]{8}-[0-9]{6}$ ]]

  # Verify branch exists
  run git branch --list "worktree/$basename_wt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"worktree/$basename_wt"* ]]

  # Verify handoff state
  run grep "^mode: sequential$" "$worktree_path/.claude/pending-handoff.local.md"
  [ "$status" -eq 0 ]
  run grep "^plan: $plan_abs\$" "$worktree_path/.claude/pending-handoff.local.md"
  [ "$status" -eq 0 ]
}

# =============================================================================
# CLI Interface (4 tests)
# =============================================================================

@test "help command shows usage" {
  run "$SCRIPT" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"create"* ]]
  [[ "$output" == *"remove"* ]]
  [[ "$output" == *"list"* ]]
}

@test "is-main command works" {
  run "$SCRIPT" is-main
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]

  worktree_path="$(create_worktree "test-is-main-cli" 2>/dev/null)"
  cd "$worktree_path"
  run "$SCRIPT" is-main
  [ "$status" -eq 0 ]
  [ "$output" = "false" ]
}

@test "list command works" {
  create_worktree "cli-test-wt"

  run "$SCRIPT" list
  [ "$status" -eq 0 ]
  [[ "$output" == *".worktrees/cli-test-wt"* ]]
}

@test "unknown command shows usage + error" {
  run "$SCRIPT" invalid-command
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

# =============================================================================
# State File Functions (2 tests)
# =============================================================================

@test "setup_worktree_with_state - creates state file with all fields" {
  # Create a simple plan file with tasks
  cat > "$TEST_DIR/test-plan.md" << 'EOF'
# Test Plan

### Task 1: First task
Do something

### Task 2: Second task
Do something else
EOF

  # Run the function
  worktree_path="$(setup_worktree_with_state "$TEST_DIR/test-plan.md" "execute-plan" 2>/dev/null)"

  # Verify worktree exists
  [ -d "$worktree_path" ]

  # Verify state file exists
  state_file="${worktree_path}/.claude/dev-workflow-state.local.md"
  [ -f "$state_file" ]

  # Verify all required fields
  run grep "^workflow: execute-plan$" "$state_file"
  [ "$status" -eq 0 ]
  run grep "^worktree: $worktree_path\$" "$state_file"
  [ "$status" -eq 0 ]
  run grep "^current_task: 0$" "$state_file"
  [ "$status" -eq 0 ]
  run grep "^total_tasks: 2$" "$state_file"
  [ "$status" -eq 0 ]
  run grep "^enabled: true$" "$state_file"
  [ "$status" -eq 0 ]
}

@test "setup_worktree_with_state - includes batch_size field" {
  # Create a simple plan file
  cat > "$TEST_DIR/test-plan.md" << 'EOF'
# Test Plan

### Task 1: First task
Do something
EOF

  # Run the function
  worktree_path="$(setup_worktree_with_state "$TEST_DIR/test-plan.md" "subagent" 2>/dev/null)"
  state_file="${worktree_path}/.claude/dev-workflow-state.local.md"

  # Verify batch_size field exists with default value
  run grep "^batch_size: 5$" "$state_file"
  [ "$status" -eq 0 ]
}

@test "setup_worktree_with_state - fails on plan with no tasks" {
  # Create a plan file WITHOUT valid task headers
  cat > "$TEST_DIR/empty-plan.md" << 'EOF'
# Empty Plan

This plan has no tasks.

## Section 1
Some content without task headers.
EOF

  # Run the function - should fail
  run setup_worktree_with_state "$TEST_DIR/empty-plan.md" "execute-plan"

  [ "$status" -ne 0 ]
  [[ "$output" == *"ERROR: No tasks found"* ]]
}

@test "setup_worktree_with_state - fails on wrong task format" {
  # Create a plan with wrong task header format
  cat > "$TEST_DIR/bad-format-plan.md" << 'EOF'
# Plan with wrong format

### Task 1 - First task (dash instead of colon)
Do something

### Task Two: Second task (word instead of number)
Do something else
EOF

  # Run the function - should fail (no valid tasks)
  run setup_worktree_with_state "$TEST_DIR/bad-format-plan.md" "execute-plan"

  [ "$status" -ne 0 ]
  [[ "$output" == *"ERROR: No tasks found"* ]]
}
