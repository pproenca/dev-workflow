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
  # Dots and non-alphanumeric chars are stripped
  [[ "$output" =~ ^my-planmd-[0-9]{8}-[0-9]{6}$ ]]
}

@test "generate_worktree_name - plan path with slashes (strips non-alphanumeric)" {
  run generate_worktree_name "/path/to/some/plan-file.md"
  [ "$status" -eq 0 ]
  # Slashes, dots, and non-alphanumeric chars are stripped
  [[ "$output" =~ ^pathtosomeplan-filemd-[0-9]{8}-[0-9]{6}$ ]]
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
