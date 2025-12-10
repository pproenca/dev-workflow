#!/usr/bin/env bats

load test_helper

HOOK="$PLUGIN_ROOT/hooks/check-commit-on-subagent-stop.sh"

setup() {
  setup_git_repo
  export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
}

teardown() {
  teardown_git_repo
}

# ============================================================================
# Test 1: No state file - should approve (fast exit path)
# ============================================================================

@test "no state file - approves with fast exit" {
  cd "$TEST_DIR"

  run "$HOOK"

  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"decision": "approve"'
  assert_valid_json
}

# ============================================================================
# Test 2: State missing last_commit - should block (BUG FIX TEST)
# ============================================================================

@test "state missing last_commit - denies with reason" {
  # Create state file WITHOUT last_commit field
  mkdir -p "$TEST_DIR/.claude"
  cat > "$TEST_DIR/.claude/dev-workflow-state.local.md" << 'EOF'
---
workflow: sequential
plan: /path/to/plan.md
current_task: 1
total_tasks: 5
---
EOF
  cd "$TEST_DIR"

  run "$HOOK"

  [ "$status" -eq 2 ]
  echo "$output" | grep -q '"decision": "deny"'
  echo "$output" | grep -q "missing last_commit"
  assert_valid_json
}

# ============================================================================
# Test 3: Git unavailable - should approve (can't determine state file path)
# ============================================================================

@test "not in git repo - approves (fast exit)" {
  # Create state with last_commit
  create_state_file "$TEST_DIR" 1 5
  cd "$TEST_DIR"

  # Make git fail by removing .git directory
  rm -rf .git

  run "$HOOK"

  # When not in a git repo, get_state_file returns empty, so fast exit approves
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"decision": "approve"'
  assert_valid_json
}

# ============================================================================
# Test 4: last_commit == HEAD - should block (no new commit)
# ============================================================================

@test "last_commit equals HEAD - denies with no commit message" {
  # Create state with current HEAD as last_commit
  create_state_file "$TEST_DIR" 1 5
  cd "$TEST_DIR"

  run "$HOOK"

  [ "$status" -eq 2 ]
  echo "$output" | grep -q '"decision": "deny"'
  echo "$output" | grep -q "No commit detected"
  assert_valid_json
}

# ============================================================================
# Test 5: last_commit != HEAD - should approve (new commit exists)
# ============================================================================

@test "new commit exists - approves" {
  # Create state with current HEAD
  create_state_file "$TEST_DIR" 1 5
  cd "$TEST_DIR"

  # Make a new commit
  echo "new content" >> file.txt
  git add file.txt
  git commit -m "New commit"

  run "$HOOK"

  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"decision": "approve"'
  assert_valid_json
}

# ============================================================================
# Test 6: Empty last_commit value - should block
# ============================================================================

@test "empty last_commit value - denies with reason" {
  # Create state with empty last_commit
  mkdir -p "$TEST_DIR/.claude"
  cat > "$TEST_DIR/.claude/dev-workflow-state.local.md" << 'EOF'
---
workflow: sequential
plan: /path/to/plan.md
current_task: 1
total_tasks: 5
last_commit:
---
EOF
  cd "$TEST_DIR"

  run "$HOOK"

  [ "$status" -eq 2 ]
  echo "$output" | grep -q '"decision": "deny"'
  echo "$output" | grep -q "missing last_commit"
  assert_valid_json
}

# ============================================================================
# Test 7: Malformed state file - should block
# ============================================================================

@test "malformed state file - denies gracefully" {
  # Create malformed state file (missing closing ---)
  mkdir -p "$TEST_DIR/.claude"
  cat > "$TEST_DIR/.claude/dev-workflow-state.local.md" << 'EOF'
---
workflow: sequential
plan: /path/to/plan.md
This is malformed - no closing delimiter
EOF
  cd "$TEST_DIR"

  run "$HOOK"

  [ "$status" -eq 2 ]
  echo "$output" | grep -q '"decision": "deny"'
  assert_valid_json
}

# ============================================================================
# Test 8: Output is valid JSON
# ============================================================================

@test "all outputs are valid JSON format" {
  # Test approve path
  cd "$TEST_DIR"
  run "$HOOK"
  [ "$status" -eq 0 ]
  assert_valid_json

  # Test deny path
  create_state_file "$TEST_DIR" 1 5
  cd "$TEST_DIR"
  run "$HOOK"
  [ "$status" -eq 2 ]
  assert_valid_json
}

# ============================================================================
# Test 9: Exit codes per hook protocol (0=approve, 2=deny)
# ============================================================================

@test "exit codes follow hook protocol - 0 for approve, 2 for deny" {
  # Test approve scenario - exit 0
  cd "$TEST_DIR"
  run "$HOOK"
  [ "$status" -eq 0 ]

  # Test deny scenario - exit 2
  create_state_file "$TEST_DIR" 1 5
  cd "$TEST_DIR"
  run "$HOOK"
  [ "$status" -eq 2 ]

  # Test error scenario (missing last_commit) - exit 2
  mkdir -p "$TEST_DIR/.claude"
  cat > "$TEST_DIR/.claude/dev-workflow-state.local.md" << 'EOF'
---
workflow: sequential
---
EOF
  cd "$TEST_DIR"
  run "$HOOK"
  [ "$status" -eq 2 ]
}

# ============================================================================
# Test 10: Works with special characters in paths
# ============================================================================

@test "handles special characters in git commit hash" {
  # Create state with current HEAD
  create_state_file "$TEST_DIR" 1 5
  cd "$TEST_DIR"

  # Make a new commit with special characters in message
  echo "special content" >> file.txt
  git add file.txt
  git commit -m "Fix: handle /path/to/file & special chars"

  run "$HOOK"

  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"decision": "approve"'
  assert_valid_json
}
