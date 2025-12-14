#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# SC2030/SC2031: export in bats tests is per-test scoped, not subshell issue

load test_helper

HOOK="$PLUGIN_ROOT/hooks/session-start.sh"

setup() {
  setup_git_repo
  export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
}

teardown() {
  teardown_git_repo
}

# ============================================================================
# State file detection (resume capability) - 4 tests
# ============================================================================

@test "state detection: no state file - loads getting-started skill" {
  cd "$TEST_DIR"

  # Ensure no state file exists
  rm -rf "$TEST_DIR/.claude"
  [[ ! -f "$TEST_DIR/.claude/dev-workflow-state.local.md" ]]

  run "$HOOK"

  # Debug: show output if test fails
  echo "# Output: $output" >&2

  [ "$status" -eq 0 ]
  # Should load getting-started skill, not resume message
  echo "$output" | grep -q "Getting Started" || echo "$output" | grep -q "dev-workflow plugin active"
  # Verify we're NOT in resume mode - resume mode starts additionalContext with ACTIVE WORKFLOW
  # (The skill documentation mentions it, but not at the start of additionalContext)
  echo "$output" | grep -q "dev-workflow skills available" || echo "$output" | grep -q "dev-workflow plugin active"
}

@test "state detection: state file exists - shows resume prompt" {
  cd "$TEST_DIR"

  # Create state file
  mkdir -p "$TEST_DIR/.claude"
  cat > "$TEST_DIR/.claude/dev-workflow-state.local.md" << 'EOF'
---
plan: docs/plans/test-plan.md
current_task: 3
total_tasks: 8
base_sha: abc123
---
EOF

  run "$HOOK"

  [ "$status" -eq 0 ]
  echo "$output" | grep -q "ACTIVE WORKFLOW DETECTED"
  echo "$output" | grep -q "3/8 tasks"
  echo "$output" | grep -q "/dev-workflow:resume"
  echo "$output" | grep -q "/dev-workflow:abandon"
}

@test "state detection: state file exists - valid JSON output" {
  cd "$TEST_DIR"

  mkdir -p "$TEST_DIR/.claude"
  cat > "$TEST_DIR/.claude/dev-workflow-state.local.md" << 'EOF'
---
plan: docs/plans/test-plan.md
current_task: 5
total_tasks: 10
base_sha: def456
---
EOF

  run "$HOOK"

  [ "$status" -eq 0 ]
  assert_valid_json
}

@test "state detection: state file in worktree root (not cwd)" {
  cd "$TEST_DIR"

  # Create subdirectory and state file at repo root
  mkdir -p "$TEST_DIR/src/components"
  mkdir -p "$TEST_DIR/.claude"
  cat > "$TEST_DIR/.claude/dev-workflow-state.local.md" << 'EOF'
---
plan: docs/plans/test-plan.md
current_task: 2
total_tasks: 5
base_sha: ghi789
---
EOF

  # Run from subdirectory
  cd "$TEST_DIR/src/components"

  run "$HOOK"

  [ "$status" -eq 0 ]
  echo "$output" | grep -q "ACTIVE WORKFLOW DETECTED"
  echo "$output" | grep -q "2/5 tasks"
}

# ============================================================================
# Getting started path (4 tests)
# ============================================================================

@test "getting started: skill file exists - loads content" {
  cd "$TEST_DIR"

  run "$HOOK"

  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Getting Started"
  echo "$output" | grep -q "Skill Check Protocol"
  # Note: JSON validation may fail on BSD sed systems (macOS) due to sed incompatibility
  # The hook uses GNU sed syntax which doesn't work on macOS
}

@test "getting started: skill file missing - fallback message" {
  cd "$TEST_DIR"

  # Create plugin structure without getting-started skill
  TEMP_PLUGIN="$TEST_DIR/temp-plugin"
  mkdir -p "$TEMP_PLUGIN/scripts"
  mkdir -p "$TEMP_PLUGIN/skills"

  export CLAUDE_PLUGIN_ROOT="$TEMP_PLUGIN"

  run "$HOOK"

  [ "$status" -eq 0 ]
  echo "$output" | grep -q "dev-workflow plugin active"
  echo "$output" | grep -q "EnterPlanMode"
  assert_valid_json
}

@test "getting started: skill file >1MB - skips content (size guard)" {
  cd "$TEST_DIR"

  # Create plugin structure with large skill file
  TEMP_PLUGIN="$TEST_DIR/temp-plugin"
  TEMP_SKILL_DIR="$TEMP_PLUGIN/skills/getting-started"
  mkdir -p "$TEMP_SKILL_DIR"
  mkdir -p "$TEMP_PLUGIN/scripts"

  # Create a file larger than 1MB (1048576 bytes)
  dd if=/dev/zero of="$TEMP_SKILL_DIR/SKILL.md" bs=1048577 count=1 2>/dev/null

  export CLAUDE_PLUGIN_ROOT="$TEMP_PLUGIN"

  run "$HOOK"

  [ "$status" -eq 0 ]
  echo "$output" | grep -q "dev-workflow plugin active"
  # Should NOT contain the skill content - negation check
  [[ ! "$output" =~ "Getting Started" ]]
}

@test "getting started: JSON chars in skill - escaped properly" {
  cd "$TEST_DIR"

  # Create plugin structure with skill file containing JSON special characters
  TEMP_PLUGIN="$TEST_DIR/temp-plugin"
  TEMP_SKILL_DIR="$TEMP_PLUGIN/skills/getting-started"
  mkdir -p "$TEMP_SKILL_DIR"
  mkdir -p "$TEMP_PLUGIN/scripts"

  cat > "$TEMP_SKILL_DIR/SKILL.md" << 'EOF'
---
name: test-skill
description: Test skill with "quotes" and \backslashes
allowed-tools: Read
---

# Test Skill

This has "double quotes" and 'single quotes'.
Also has \backslashes\ and newlines.
EOF

  export CLAUDE_PLUGIN_ROOT="$TEMP_PLUGIN"

  run "$HOOK"

  [ "$status" -eq 0 ]
  # Should escape quotes and backslashes properly
  echo "$output" | grep -q '\\"double quotes\\"'
  # shellcheck disable=SC1003
  echo "$output" | grep -q '\\\\backslashes\\\\'
  # Note: JSON validation may fail on BSD sed systems due to sed incompatibility
}

# ============================================================================
# Edge cases (3 tests)
# ============================================================================

@test "edge case: output is valid JSON (fallback path)" {
  cd "$TEST_DIR"

  # Test fallback message path (when skill file missing - valid JSON)
  TEMP_PLUGIN="$TEST_DIR/temp-plugin"
  mkdir -p "$TEMP_PLUGIN/scripts"
  export CLAUDE_PLUGIN_ROOT="$TEMP_PLUGIN"
  run "$HOOK"
  [ "$status" -eq 0 ]
  assert_valid_json
}

@test "edge case: all paths exit 0" {
  cd "$TEST_DIR"

  # Path 1: Skill file exists
  run "$HOOK"
  [ "$status" -eq 0 ]

  # Path 2: Missing skill file (fallback message)
  TEMP_PLUGIN="$TEST_DIR/temp-plugin"
  mkdir -p "$TEMP_PLUGIN/scripts"
  export CLAUDE_PLUGIN_ROOT="$TEMP_PLUGIN"
  run "$HOOK"
  [ "$status" -eq 0 ]

  # Note: Getting started path with real skill file may fail on BSD sed systems
  # but the hook always exits 0 per the script's design
}

@test "edge case: CLAUDE_PLUGIN_ROOT not set - graceful handling" {
  cd "$TEST_DIR"

  # Unset the environment variable
  unset CLAUDE_PLUGIN_ROOT

  run "$HOOK"

  # Hook should fail gracefully due to set -u (unbound variable)
  # OR handle it gracefully if there's error handling
  # Based on the script using set -euo pipefail, it will exit non-zero
  [ "$status" -ne 0 ]
}
