#!/usr/bin/env bats

load test_helper

HOOK="$PLUGIN_ROOT/hooks/check-state-on-stop.sh"

setup() {
  setup_git_repo
  export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
}

teardown() {
  teardown_git_repo
}

# ============================================================================
# Test 1: No state file - exits silently with exit 0
# ============================================================================

@test "no state file - exits silently with code 0" {
  cd "$TEST_DIR"

  run "$HOOK"

  [ "$status" -eq 0 ]
  # Should have no output when state file doesn't exist (fast exit path)
  [ -z "$output" ]
}

# ============================================================================
# Test 2: State file exists - shows workflow progress message
# ============================================================================

@test "state file exists - outputs workflow progress message" {
  create_state_file "$TEST_DIR" 3 7
  cd "$TEST_DIR"

  run "$HOOK"

  [ "$status" -eq 0 ]
  # Should show progress in output
  echo "$output" | grep -q "Progress: Task 3/7"
  # Should mention workflow is active
  echo "$output" | grep -q "WORKFLOW ACTIVE"
  # Should mention execution-plan command
  echo "$output" | grep -q "execute-plan"
}

# ============================================================================
# Test 3: Missing current_task field - defaults to 0
# ============================================================================

@test "missing current_task field - defaults to 0" {
  mkdir -p "$TEST_DIR/.claude"
  cat > "$TEST_DIR/.claude/dev-workflow-state.local.md" << 'EOF'
---
workflow: sequential
plan: /path/to/plan.md
total_tasks: 5
last_commit: abc123
---
EOF
  cd "$TEST_DIR"

  run "$HOOK"

  [ "$status" -eq 0 ]
  # Should default to 0 for current_task
  echo "$output" | grep -q "Progress: Task 0/5"
  assert_valid_json
}

# ============================================================================
# Test 4: Missing total_tasks field - defaults to 0
# ============================================================================

@test "missing total_tasks field - defaults to 0" {
  mkdir -p "$TEST_DIR/.claude"
  cat > "$TEST_DIR/.claude/dev-workflow-state.local.md" << 'EOF'
---
workflow: sequential
plan: /path/to/plan.md
current_task: 2
last_commit: abc123
---
EOF
  cd "$TEST_DIR"

  run "$HOOK"

  [ "$status" -eq 0 ]
  # Should default to 0 for total_tasks
  echo "$output" | grep -q "Progress: Task 2/0"
  assert_valid_json
}

# ============================================================================
# Test 5: Output is valid JSON format
# ============================================================================

@test "output is valid JSON format" {
  create_state_file "$TEST_DIR" 1 5
  cd "$TEST_DIR"

  run "$HOOK"

  [ "$status" -eq 0 ]
  # Verify JSON structure
  echo "$output" | grep -q '"hookSpecificOutput"'
  echo "$output" | grep -q '"hookEventName": "Stop"'
  echo "$output" | grep -q '"additionalContext"'
  # Validate full JSON
  assert_valid_json
}

# ============================================================================
# Test 6: Exit code is always 0 (hook protocol requirement)
# ============================================================================

@test "exit code is always 0 regardless of state conditions" {
  # Test 1: No state file
  cd "$TEST_DIR"
  run "$HOOK"
  [ "$status" -eq 0 ]

  # Test 2: With state file
  create_state_file "$TEST_DIR" 2 4
  cd "$TEST_DIR"
  run "$HOOK"
  [ "$status" -eq 0 ]

  # Test 3: Both fields missing
  mkdir -p "$TEST_DIR/.claude"
  cat > "$TEST_DIR/.claude/dev-workflow-state.local.md" << 'EOF'
---
workflow: sequential
plan: /path/to/plan.md
---
EOF
  cd "$TEST_DIR"
  run "$HOOK"
  [ "$status" -eq 0 ]
}
