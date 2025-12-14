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
