#!/usr/bin/env bats

load test_helper

SCRIPT="$PLUGIN_ROOT/scripts/hook-helpers.sh"

setup() {
  setup_test_dir
  # shellcheck source=../scripts/hook-helpers.sh disable=SC1091
  source "$SCRIPT"
}

teardown() {
  teardown_test_dir
}

# ============================================================================
# frontmatter_get() tests
# ============================================================================

@test "frontmatter_get: file does not exist - returns default" {
  result=$(frontmatter_get "$TEST_DIR/nonexistent.md" "key" "default_value")
  [[ "$result" == "default_value" ]]
}

@test "frontmatter_get: key exists with simple value" {
  cat > "$TEST_DIR/test.md" << 'EOF'
---
name: test-value
status: active
---
Content here
EOF
  result=$(frontmatter_get "$TEST_DIR/test.md" "name")
  [[ "$result" == "test-value" ]]
}

@test "frontmatter_get: key missing - returns default" {
  cat > "$TEST_DIR/test.md" << 'EOF'
---
name: test-value
---
Content here
EOF
  result=$(frontmatter_get "$TEST_DIR/test.md" "missing_key" "default_val")
  [[ "$result" == "default_val" ]]
}

@test "frontmatter_get: empty value - returns default" {
  cat > "$TEST_DIR/test.md" << 'EOF'
---
name:
status: active
---
Content here
EOF
  result=$(frontmatter_get "$TEST_DIR/test.md" "name" "default_val")
  [[ "$result" == "default_val" ]]
}

@test "frontmatter_get: null value - returns default" {
  cat > "$TEST_DIR/test.md" << 'EOF'
---
name: null
status: active
---
Content here
EOF
  result=$(frontmatter_get "$TEST_DIR/test.md" "name" "default_val")
  [[ "$result" == "default_val" ]]
}

@test "frontmatter_get: key in body vs frontmatter - only matches frontmatter" {
  cat > "$TEST_DIR/test.md" << 'EOF'
---
name: frontmatter_value
---
name: body_value
EOF
  result=$(frontmatter_get "$TEST_DIR/test.md" "name")
  [[ "$result" == "frontmatter_value" ]]
}

@test "frontmatter_get: duplicate keys - returns first" {
  cat > "$TEST_DIR/test.md" << 'EOF'
---
name: first_value
name: second_value
---
Content here
EOF
  result=$(frontmatter_get "$TEST_DIR/test.md" "name")
  [[ "$result" == "first_value" ]]
}

@test "frontmatter_get: value with double quotes - strips quotes" {
  cat > "$TEST_DIR/test.md" << 'EOF'
---
name: "quoted value"
---
Content here
EOF
  result=$(frontmatter_get "$TEST_DIR/test.md" "name")
  [[ "$result" == "quoted value" ]]
}

@test "frontmatter_get: value with single quotes - strips quotes" {
  cat > "$TEST_DIR/test.md" << 'EOF'
---
name: 'single quoted'
---
Content here
EOF
  result=$(frontmatter_get "$TEST_DIR/test.md" "name")
  [[ "$result" == "single quoted" ]]
}

@test "frontmatter_get: value with forward slash" {
  cat > "$TEST_DIR/test.md" << 'EOF'
---
path: /path/to/file
---
Content here
EOF
  result=$(frontmatter_get "$TEST_DIR/test.md" "path")
  [[ "$result" == "/path/to/file" ]]
}

@test "frontmatter_get: value with ampersand" {
  cat > "$TEST_DIR/test.md" << 'EOF'
---
name: foo&bar
---
Content here
EOF
  result=$(frontmatter_get "$TEST_DIR/test.md" "name")
  [[ "$result" == "foo&bar" ]]
}

@test "frontmatter_get: value with backslash" {
  cat > "$TEST_DIR/test.md" << 'EOF'
---
path: C:\Users\test
---
Content here
EOF
  result=$(frontmatter_get "$TEST_DIR/test.md" "path")
  [[ "$result" == "C:\Users\test" ]]
}

@test "frontmatter_get: value with colons (URLs)" {
  cat > "$TEST_DIR/test.md" << 'EOF'
---
url: https://example.com:8080/path
---
Content here
EOF
  result=$(frontmatter_get "$TEST_DIR/test.md" "url")
  [[ "$result" == "https://example.com:8080/path" ]]
}

@test "frontmatter_get: nested quotes in value" {
  # Note: The outer quotes get stripped by frontmatter_get
  cat > "$TEST_DIR/test.md" << 'EOF'
---
message: "He said \"hello\""
---
Content here
EOF
  result=$(frontmatter_get "$TEST_DIR/test.md" "message")
  # After stripping outer quotes, we get the inner content with escaped quotes
  [[ "$result" == 'He said \"hello\"' ]]
}

@test "frontmatter_get: missing closing frontmatter delimiter" {
  cat > "$TEST_DIR/test.md" << 'EOF'
---
name: test-value
Content here without closing ---
EOF
  result=$(frontmatter_get "$TEST_DIR/test.md" "name" "default_val")
  # Should handle gracefully - may return empty or default
  [[ -n "$result" ]]
}

@test "frontmatter_get: empty file" {
  touch "$TEST_DIR/empty.md"
  result=$(frontmatter_get "$TEST_DIR/empty.md" "name" "default_val")
  [[ "$result" == "default_val" ]]
}

# ============================================================================
# frontmatter_set() tests - THESE SHOULD FAIL INITIALLY
# ============================================================================

@test "frontmatter_set: key exists - updates value" {
  cat > "$TEST_DIR/test.md" << 'EOF'
---
name: old_value
status: active
---
Content here
EOF
  frontmatter_set "$TEST_DIR/test.md" "name" "new_value"
  result=$(frontmatter_get "$TEST_DIR/test.md" "name")
  [[ "$result" == "new_value" ]]
}

@test "frontmatter_set: key missing - returns error" {
  cat > "$TEST_DIR/test.md" << 'EOF'
---
name: test-value
---
Content here
EOF
  run frontmatter_set "$TEST_DIR/test.md" "missing_key" "some_value"
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "Error: Key 'missing_key' not found" ]]
}

@test "frontmatter_set: atomic write - uses temp file" {
  cat > "$TEST_DIR/test.md" << 'EOF'
---
name: old_value
---
Content here
EOF
  frontmatter_set "$TEST_DIR/test.md" "name" "new_value"
  # Verify no temp file left behind
  temp_count=$(find "$TEST_DIR" -name "test.md.tmp.*" | wc -l)
  [[ "$temp_count" -eq 0 ]]
  # Verify content updated
  result=$(frontmatter_get "$TEST_DIR/test.md" "name")
  [[ "$result" == "new_value" ]]
}

@test "frontmatter_set: value with forward slash - SHOULD FAIL BEFORE FIX" {
  cat > "$TEST_DIR/test.md" << 'EOF'
---
path: placeholder
status: active
---
Content here
EOF
  frontmatter_set "$TEST_DIR/test.md" "path" "/path/to/file"
  result=$(frontmatter_get "$TEST_DIR/test.md" "path")
  [[ "$result" == "/path/to/file" ]]
}

@test "frontmatter_set: value with ampersand - SHOULD FAIL BEFORE FIX" {
  cat > "$TEST_DIR/test.md" << 'EOF'
---
name: placeholder
status: active
---
Content here
EOF
  frontmatter_set "$TEST_DIR/test.md" "name" "foo&bar"
  result=$(frontmatter_get "$TEST_DIR/test.md" "name")
  [[ "$result" == "foo&bar" ]]
}

@test "frontmatter_set: value with backslash - SHOULD FAIL BEFORE FIX" {
  cat > "$TEST_DIR/test.md" << 'EOF'
---
path: placeholder
status: active
---
Content here
EOF
  frontmatter_set "$TEST_DIR/test.md" "path" "C:\Users\test"
  result=$(frontmatter_get "$TEST_DIR/test.md" "path")
  [[ "$result" == "C:\Users\test" ]]
}

@test "frontmatter_set: value with pipe character - regression test for bug fix" {
  cat > "$TEST_DIR/test.md" << 'EOF'
---
path: placeholder
status: active
---
Content here
EOF
  # Pipe character was breaking sed because | is used as delimiter
  frontmatter_set "$TEST_DIR/test.md" "path" "path/to/file|with|pipes"
  result=$(frontmatter_get "$TEST_DIR/test.md" "path")
  [[ "$result" == "path/to/file|with|pipes" ]]
}

@test "frontmatter_set: nested directory path" {
  cat > "$TEST_DIR/test.md" << 'EOF'
---
path: placeholder
status: active
---
Content here
EOF
  frontmatter_set "$TEST_DIR/test.md" "path" "/very/long/nested/directory/path/to/file.txt"
  result=$(frontmatter_get "$TEST_DIR/test.md" "path")
  [[ "$result" == "/very/long/nested/directory/path/to/file.txt" ]]
}

# ============================================================================
# output_json() tests
# ============================================================================

@test "output_json: simple message" {
  result=$(output_json "Hello World")
  echo "$result" | grep -q '"additionalContext": "Hello World"'
}

@test "output_json: message with newlines" {
  result=$(output_json "Line 1
Line 2
Line 3")
  echo "$result" | grep -q '"additionalContext": "Line 1\\nLine 2\\nLine 3"'
}

@test "output_json: message with double quotes" {
  result=$(output_json 'He said "hello"')
  echo "$result" | grep -q 'He said \\"hello\\"'
}

@test "output_json: message with backslashes" {
  result=$(output_json 'C:\Users\test')
  echo "$result" | grep -q 'C:\\\\Users\\\\test'
}

# ============================================================================
# get_state_file() tests
# ============================================================================

@test "get_state_file: returns absolute path in git repo" {
  teardown_test_dir  # cleanup first
  setup_git_repo
  result=$(get_state_file)
  # Should return absolute path
  [[ "$result" == /* ]]
  teardown_git_repo
}

@test "get_state_file: path contains expected suffix" {
  teardown_test_dir
  setup_git_repo
  result=$(get_state_file)
  [[ "$result" == *"/.claude/dev-workflow-state.local.md" ]]
  teardown_git_repo
}

@test "get_state_file: works from subdirectory of repo" {
  teardown_test_dir
  setup_git_repo
  mkdir -p "$TEST_DIR/deep/nested/dir"
  cd "$TEST_DIR/deep/nested/dir"
  result=$(get_state_file)
  # Should still return path to repo root
  [[ "$result" == "$TEST_DIR/.claude/dev-workflow-state.local.md" ]]
  teardown_git_repo
}

@test "get_state_file: from nested subdirectory (3 levels deep)" {
  teardown_test_dir
  setup_git_repo
  mkdir -p "$TEST_DIR/level1/level2/level3"
  cd "$TEST_DIR/level1/level2/level3"
  result=$(get_state_file)
  [[ "$result" == "$TEST_DIR/.claude/dev-workflow-state.local.md" ]]
  teardown_git_repo
}

@test "get_state_file: consistent across multiple calls" {
  teardown_test_dir
  setup_git_repo
  result1=$(get_state_file)
  result2=$(get_state_file)
  [[ "$result1" == "$result2" ]]
  teardown_git_repo
}

@test "get_state_file: returns empty string outside git repo" {
  teardown_test_dir
  setup_test_dir
  cd "$TEST_DIR"
  result=$(get_state_file)
  [[ -z "$result" ]]
  teardown_test_dir
}

# ============================================================================
# get_handoff_file() tests
# ============================================================================

@test "get_handoff_file: returns absolute path in git repo" {
  teardown_test_dir
  setup_git_repo
  result=$(get_handoff_file)
  [[ "$result" == /* ]]
  teardown_git_repo
}

@test "get_handoff_file: path contains expected suffix" {
  teardown_test_dir
  setup_git_repo
  result=$(get_handoff_file)
  [[ "$result" == *"/.claude/pending-handoff.local.md" ]]
  teardown_git_repo
}

@test "get_handoff_file: works from subdirectory of repo" {
  teardown_test_dir
  setup_git_repo
  mkdir -p "$TEST_DIR/subdir"
  cd "$TEST_DIR/subdir"
  result=$(get_handoff_file)
  [[ "$result" == "$TEST_DIR/.claude/pending-handoff.local.md" ]]
  teardown_git_repo
}

@test "get_handoff_file: returns empty string outside git repo" {
  teardown_test_dir
  setup_test_dir
  cd "$TEST_DIR"
  result=$(get_handoff_file)
  [[ -z "$result" ]]
  teardown_test_dir
}

# ============================================================================
# has_active_workflow() tests (requires git repo)
# ============================================================================

@test "has_active_workflow: file exists in git repo" {
  teardown_test_dir
  setup_git_repo
  mkdir -p "$TEST_DIR/.claude"
  touch "$TEST_DIR/.claude/dev-workflow-state.local.md"
  cd "$TEST_DIR"
  run has_active_workflow
  [[ "$status" -eq 0 ]]
  teardown_git_repo
}

@test "has_active_workflow: no file in git repo" {
  teardown_test_dir
  setup_git_repo
  cd "$TEST_DIR"
  run has_active_workflow
  [[ "$status" -ne 0 ]]
  teardown_git_repo
}

@test "has_active_workflow: works from subdirectory" {
  teardown_test_dir
  setup_git_repo
  mkdir -p "$TEST_DIR/.claude"
  touch "$TEST_DIR/.claude/dev-workflow-state.local.md"
  mkdir -p "$TEST_DIR/subdir"
  cd "$TEST_DIR/subdir"
  run has_active_workflow
  [[ "$status" -eq 0 ]]
  teardown_git_repo
}

# ============================================================================
# has_pending_handoff() tests (requires git repo)
# ============================================================================

@test "has_pending_handoff: file exists in git repo" {
  teardown_test_dir
  setup_git_repo
  mkdir -p "$TEST_DIR/.claude"
  touch "$TEST_DIR/.claude/pending-handoff.local.md"
  cd "$TEST_DIR"
  run has_pending_handoff
  [[ "$status" -eq 0 ]]
  teardown_git_repo
}

@test "has_pending_handoff: no file in git repo" {
  teardown_test_dir
  setup_git_repo
  cd "$TEST_DIR"
  run has_pending_handoff
  [[ "$status" -ne 0 ]]
  teardown_git_repo
}

@test "has_pending_handoff: works from subdirectory" {
  teardown_test_dir
  setup_git_repo
  mkdir -p "$TEST_DIR/.claude"
  touch "$TEST_DIR/.claude/pending-handoff.local.md"
  mkdir -p "$TEST_DIR/subdir"
  cd "$TEST_DIR/subdir"
  run has_pending_handoff
  [[ "$status" -eq 0 ]]
  teardown_git_repo
}

# ============================================================================
# Integration: frontmatter functions with get_state_file
# ============================================================================

@test "frontmatter_get: using get_state_file path" {
  teardown_test_dir
  setup_git_repo
  STATE_FILE="$(get_state_file)"
  mkdir -p "$(dirname "$STATE_FILE")"
  cat > "$STATE_FILE" << 'EOF'
---
workflow: execute-plan
current_task: 3
---
EOF
  result=$(frontmatter_get "$STATE_FILE" "current_task")
  [[ "$result" == "3" ]]
  teardown_git_repo
}

@test "frontmatter_set: using get_state_file path" {
  teardown_test_dir
  setup_git_repo
  STATE_FILE="$(get_state_file)"
  mkdir -p "$(dirname "$STATE_FILE")"
  cat > "$STATE_FILE" << 'EOF'
---
workflow: execute-plan
current_task: 3
---
EOF
  frontmatter_set "$STATE_FILE" "current_task" "4"
  result=$(frontmatter_get "$STATE_FILE" "current_task")
  [[ "$result" == "4" ]]
  teardown_git_repo
}

@test "integration: get then set roundtrip" {
  cat > "$TEST_DIR/test.md" << 'EOF'
---
name: original
status: active
path: /home/user
---
Content here
EOF
  # Read original
  original=$(frontmatter_get "$TEST_DIR/test.md" "name")
  [[ "$original" == "original" ]]

  # Update
  frontmatter_set "$TEST_DIR/test.md" "name" "updated"

  # Verify update
  updated=$(frontmatter_get "$TEST_DIR/test.md" "name")
  [[ "$updated" == "updated" ]]

  # Verify other fields unchanged
  status=$(frontmatter_get "$TEST_DIR/test.md" "status")
  [[ "$status" == "active" ]]

  path=$(frontmatter_get "$TEST_DIR/test.md" "path")
  [[ "$path" == "/home/user" ]]
}
