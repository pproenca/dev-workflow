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
# frontmatter_set() tests
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

@test "frontmatter_set: value with forward slash" {
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

@test "frontmatter_set: value with ampersand" {
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

@test "frontmatter_set: value with backslash" {
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
# Integration: get then set roundtrip
# ============================================================================

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

# ============================================================================
# get_state_file() tests
# ============================================================================

@test "get_state_file: in git repo - returns correct path" {
  # Initialize git repo in test dir
  cd "$TEST_DIR"
  git init
  git config user.email "test@test.com"
  git config user.name "Test"

  result=$(get_state_file)
  [[ "$result" == "$TEST_DIR/.claude/dev-workflow-state.local.md" ]]
}

@test "get_state_file: not in git repo - returns error" {
  cd "$TEST_DIR"
  # Ensure not in a git repo (TEST_DIR is created fresh each test)

  run get_state_file
  [[ "$status" -eq 1 ]]
}

@test "get_state_file: from subdirectory - still returns repo root path" {
  cd "$TEST_DIR"
  git init
  git config user.email "test@test.com"
  git config user.name "Test"

  mkdir -p "$TEST_DIR/src/deep/nested"
  cd "$TEST_DIR/src/deep/nested"

  result=$(get_state_file)
  [[ "$result" == "$TEST_DIR/.claude/dev-workflow-state.local.md" ]]
}

# ============================================================================
# create_state_file() tests
# ============================================================================

@test "create_state_file: creates file with correct structure" {
  cd "$TEST_DIR"
  git init
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "test" > file.txt
  git add file.txt
  git commit -m "Initial"

  # Create a plan file with tasks
  mkdir -p "$TEST_DIR/docs/plans"
  cat > "$TEST_DIR/docs/plans/test-plan.md" << 'EOF'
# Test Plan

### Task 1: First task
Content

### Task 2: Second task
Content

### Task 3: Third task
Content
EOF

  create_state_file "$TEST_DIR/docs/plans/test-plan.md"

  state_file="$TEST_DIR/.claude/dev-workflow-state.local.md"
  [[ -f "$state_file" ]]

  # Verify fields
  plan=$(frontmatter_get "$state_file" "plan")
  [[ "$plan" == "$TEST_DIR/docs/plans/test-plan.md" ]]

  current=$(frontmatter_get "$state_file" "current_task")
  [[ "$current" == "0" ]]

  total=$(frontmatter_get "$state_file" "total_tasks")
  [[ "$total" == "3" ]]

  base_sha=$(frontmatter_get "$state_file" "base_sha")
  [[ -n "$base_sha" ]]
}

@test "create_state_file: creates .claude directory if missing" {
  cd "$TEST_DIR"
  git init
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "test" > file.txt
  git add file.txt
  git commit -m "Initial"

  # Create minimal plan
  cat > "$TEST_DIR/plan.md" << 'EOF'
### Task 1: Only task
EOF

  # Ensure .claude doesn't exist
  [[ ! -d "$TEST_DIR/.claude" ]]

  create_state_file "$TEST_DIR/plan.md"

  [[ -d "$TEST_DIR/.claude" ]]
  [[ -f "$TEST_DIR/.claude/dev-workflow-state.local.md" ]]
}

@test "create_state_file: counts zero tasks for empty plan" {
  cd "$TEST_DIR"
  git init
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "test" > file.txt
  git add file.txt
  git commit -m "Initial"

  # Create plan with no tasks
  cat > "$TEST_DIR/empty-plan.md" << 'EOF'
# Empty Plan
No tasks here.
EOF

  create_state_file "$TEST_DIR/empty-plan.md"

  state_file="$TEST_DIR/.claude/dev-workflow-state.local.md"
  total=$(frontmatter_get "$state_file" "total_tasks")
  [[ "$total" == "0" ]]
}

# ============================================================================
# delete_state_file() tests
# ============================================================================

@test "delete_state_file: removes existing state file" {
  cd "$TEST_DIR"
  git init
  git config user.email "test@test.com"
  git config user.name "Test"

  mkdir -p "$TEST_DIR/.claude"
  echo "test state" > "$TEST_DIR/.claude/dev-workflow-state.local.md"
  [[ -f "$TEST_DIR/.claude/dev-workflow-state.local.md" ]]

  delete_state_file

  [[ ! -f "$TEST_DIR/.claude/dev-workflow-state.local.md" ]]
}

@test "delete_state_file: succeeds silently if file doesn't exist" {
  cd "$TEST_DIR"
  git init
  git config user.email "test@test.com"
  git config user.name "Test"

  # No state file exists
  [[ ! -f "$TEST_DIR/.claude/dev-workflow-state.local.md" ]]

  run delete_state_file

  [[ "$status" -eq 0 ]]
}

@test "delete_state_file: not in git repo - returns error" {
  cd "$TEST_DIR"
  # Not a git repo

  run delete_state_file

  [[ "$status" -eq 1 ]]
}

# ============================================================================
# get_task_files() tests
# ============================================================================

@test "get_task_files: extracts files from task section" {
  cat > "$TEST_DIR/plan.md" << 'EOF'
### Task 1: Create user model

**Files:**
- Create: `src/models/user.py`
- Test: `tests/test_user.py`

### Task 2: Next task
EOF

  result=$(get_task_files "$TEST_DIR/plan.md" "1")
  echo "$result" | grep -q "src/models/user.py"
  echo "$result" | grep -q "tests/test_user.py"
}

@test "get_task_files: handles Modify files" {
  cat > "$TEST_DIR/plan.md" << 'EOF'
### Task 1: Update config

**Files:**
- Modify: `src/config.py:10-20`
- Test: `tests/test_config.py`

### Task 2: Next task
EOF

  result=$(get_task_files "$TEST_DIR/plan.md" "1")
  echo "$result" | grep -q "src/config.py:10-20"
}

@test "get_task_files: returns empty for task with no files" {
  cat > "$TEST_DIR/plan.md" << 'EOF'
### Task 1: Documentation only

Just update README.

### Task 2: Next task
EOF

  result=$(get_task_files "$TEST_DIR/plan.md" "1")
  [[ -z "$result" ]]
}

# ============================================================================
# group_tasks_by_dependency() tests
# ============================================================================

@test "group_tasks_by_dependency: independent tasks in same group" {
  cat > "$TEST_DIR/plan.md" << 'EOF'
### Task 1: User model

**Files:**
- Create: `src/user.py`
- Test: `tests/test_user.py`

### Task 2: Product model

**Files:**
- Create: `src/product.py`
- Test: `tests/test_product.py`

### Task 3: Order model

**Files:**
- Create: `src/order.py`
- Test: `tests/test_order.py`
EOF

  result=$(group_tasks_by_dependency "$TEST_DIR/plan.md" 5)
  # All three tasks should be in one group (no overlap)
  [[ "$result" == "group1:1,2,3" ]]
}

@test "group_tasks_by_dependency: overlapping tasks in different groups" {
  cat > "$TEST_DIR/plan.md" << 'EOF'
### Task 1: Create base

**Files:**
- Create: `src/base.py`

### Task 2: Extend base

**Files:**
- Modify: `src/base.py`
- Create: `src/extended.py`

### Task 3: Independent

**Files:**
- Create: `src/other.py`
EOF

  result=$(group_tasks_by_dependency "$TEST_DIR/plan.md" 5)
  # Task 1 and 2 overlap on src/base.py, so should be in different groups
  echo "$result" | grep -q "group1:1"
  echo "$result" | grep -q "group2:2"
}

@test "group_tasks_by_dependency: respects max group size" {
  cat > "$TEST_DIR/plan.md" << 'EOF'
### Task 1: A
**Files:**
- Create: `a.py`

### Task 2: B
**Files:**
- Create: `b.py`

### Task 3: C
**Files:**
- Create: `c.py`

### Task 4: D
**Files:**
- Create: `d.py`
EOF

  # Max group size of 2
  result=$(group_tasks_by_dependency "$TEST_DIR/plan.md" 2)
  # Should split into two groups of 2
  echo "$result" | grep -q "group1:1,2"
  echo "$result" | grep -q "group2:3,4"
}

# ============================================================================
# Decimal task number support tests
# ============================================================================

@test "get_task_numbers: extracts integer task numbers" {
  cat > "$TEST_DIR/plan.md" << 'EOF'
### Task 1: First
Content

### Task 2: Second
Content

### Task 3: Third
Content
EOF

  result=$(get_task_numbers "$TEST_DIR/plan.md")
  [[ "$result" == "1 2 3" ]]
}

@test "get_task_numbers: extracts decimal task numbers" {
  cat > "$TEST_DIR/plan.md" << 'EOF'
### Task 1: Main task
Content

### Task 1.1: Subtask A
Content

### Task 1.2: Subtask B
Content

### Task 2: Another main task
Content
EOF

  result=$(get_task_numbers "$TEST_DIR/plan.md")
  [[ "$result" == "1 1.1 1.2 2" ]]
}

@test "get_task_numbers: handles mixed integer and decimal" {
  cat > "$TEST_DIR/plan.md" << 'EOF'
### Task 1: First
### Task 1.1: Sub
### Task 2: Second
### Task 2.1: Sub A
### Task 2.2: Sub B
### Task 3: Third
EOF

  result=$(get_task_numbers "$TEST_DIR/plan.md")
  [[ "$result" == "1 1.1 2 2.1 2.2 3" ]]
}

@test "get_next_task_number: returns next integer" {
  cat > "$TEST_DIR/plan.md" << 'EOF'
### Task 1: First
### Task 2: Second
### Task 3: Third
EOF

  result=$(get_next_task_number "$TEST_DIR/plan.md" "1")
  [[ "$result" == "2" ]]
}

@test "get_next_task_number: returns subtask after main task" {
  cat > "$TEST_DIR/plan.md" << 'EOF'
### Task 1: Main
### Task 1.1: Sub
### Task 2: Next main
EOF

  result=$(get_next_task_number "$TEST_DIR/plan.md" "1")
  [[ "$result" == "1.1" ]]
}

@test "get_next_task_number: returns main task after subtask" {
  cat > "$TEST_DIR/plan.md" << 'EOF'
### Task 1: Main
### Task 1.1: Sub
### Task 2: Next main
EOF

  result=$(get_next_task_number "$TEST_DIR/plan.md" "1.1")
  [[ "$result" == "2" ]]
}

@test "get_next_task_number: returns empty for last task" {
  cat > "$TEST_DIR/plan.md" << 'EOF'
### Task 1: First
### Task 2: Last
EOF

  result=$(get_next_task_number "$TEST_DIR/plan.md" "2")
  [[ -z "$result" ]]
}

@test "create_state_file: counts decimal tasks correctly" {
  cat > "$TEST_DIR/plan.md" << 'EOF'
### Task 1: Main
### Task 1.1: Sub A
### Task 1.2: Sub B
### Task 2: Another
EOF

  # Run in a temp git repo since create_state_file requires git
  cd "$TEST_DIR"
  git init -q

  create_state_file "$TEST_DIR/plan.md"
  state_file=$(get_state_file)

  total=$(frontmatter_get "$state_file" "total_tasks" "0")
  [[ "$total" == "4" ]]
}

@test "get_task_files: extracts files from decimal task" {
  cat > "$TEST_DIR/plan.md" << 'EOF'
### Task 1: Main task

**Files:**
- Create: `src/main.py`

### Task 1.1: Subtask

**Files:**
- Create: `src/sub.py`
- Test: `tests/test_sub.py`

### Task 2: Next main

**Files:**
- Create: `src/next.py`
EOF

  result=$(get_task_files "$TEST_DIR/plan.md" "1.1")
  echo "$result" | grep -q "src/sub.py"
  echo "$result" | grep -q "tests/test_sub.py"
  # Should NOT include files from other tasks
  ! echo "$result" | grep -q "src/main.py"
  ! echo "$result" | grep -q "src/next.py"
}

@test "get_task_content: extracts decimal task content" {
  cat > "$TEST_DIR/plan.md" << 'EOF'
### Task 1: Main task

Main content here.

### Task 1.1: Subtask

Subtask content here.
With multiple lines.

### Task 2: Next main

Next content.
EOF

  result=$(get_task_content "$TEST_DIR/plan.md" "1.1")
  echo "$result" | grep -q "### Task 1.1: Subtask"
  echo "$result" | grep -q "Subtask content here"
  echo "$result" | grep -q "With multiple lines"
  # Should NOT include other task content
  ! echo "$result" | grep -q "Main content here"
  ! echo "$result" | grep -q "Next content"
}

@test "get_task_content: extracts last decimal task (no next task)" {
  cat > "$TEST_DIR/plan.md" << 'EOF'
### Task 1: Main

Main content.

### Task 1.1: Last subtask

Last subtask content.
EOF

  result=$(get_task_content "$TEST_DIR/plan.md" "1.1")
  echo "$result" | grep -q "### Task 1.1: Last subtask"
  echo "$result" | grep -q "Last subtask content"
}

@test "group_tasks_by_dependency: handles decimal tasks with no overlap" {
  cat > "$TEST_DIR/plan.md" << 'EOF'
### Task 1: Main

**Files:**
- Create: `src/a.py`

### Task 1.1: Sub A

**Files:**
- Create: `src/b.py`

### Task 1.2: Sub B

**Files:**
- Create: `src/c.py`
EOF

  result=$(group_tasks_by_dependency "$TEST_DIR/plan.md" 5)
  # All tasks independent, should be in same group
  [[ "$result" == "group1:1,1.1,1.2" ]]
}

@test "group_tasks_by_dependency: handles decimal tasks with overlap" {
  cat > "$TEST_DIR/plan.md" << 'EOF'
### Task 1: Create base

**Files:**
- Create: `src/base.py`

### Task 1.1: Extend base

**Files:**
- Modify: `src/base.py`
- Create: `src/extended.py`

### Task 2: Independent

**Files:**
- Create: `src/other.py`
EOF

  result=$(group_tasks_by_dependency "$TEST_DIR/plan.md" 5)
  # Task 1 and 1.1 overlap on base.py, should be in different groups
  echo "$result" | grep -q "group1:1"
  echo "$result" | grep -q "group2:1.1"
}
