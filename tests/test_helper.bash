#!/usr/bin/env bash
# Common test helpers for bats-core tests

# Get plugin root directory
PLUGIN_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
export PLUGIN_ROOT

# Create a temporary test directory
# Use pwd -P to resolve symlinks (macOS /var -> /private/var)
setup_test_dir() {
  TEST_DIR="$(cd "$(mktemp -d)" && pwd -P)"
  export TEST_DIR
}

# Clean up temporary test directory
teardown_test_dir() {
  [[ -n "${TEST_DIR:-}" ]] && rm -rf "$TEST_DIR"
}

# Create a minimal valid command file
create_valid_command() {
  local dir="${1:-$TEST_DIR}"
  local name="${2:-test-command}"
  mkdir -p "$dir/commands"
  cat > "$dir/commands/$name.md" << 'EOF'
---
description: Test command for validation
allowed-tools: Read, Write
---

# Test Command

This is a test command.
EOF
}

# Create a command with invalid bash
create_invalid_bash_command() {
  local dir="${1:-$TEST_DIR}"
  local name="${2:-bad-bash}"
  mkdir -p "$dir/commands"
  cat > "$dir/commands/$name.md" << 'EOF'
---
description: Command with bad bash
allowed-tools: Bash
---

# Bad Command

```bash
if [ then # syntax error
```
EOF
}

# Create a minimal valid skill
create_valid_skill() {
  local dir="${1:-$TEST_DIR}"
  local name="${2:-test-skill}"
  mkdir -p "$dir/skills/$name"
  cat > "$dir/skills/$name/SKILL.md" << 'EOF'
---
name: test-skill
description: Test skill for validation
allowed-tools: Read
---

# Test Skill

This is a test skill.
EOF
}

# Create skill with missing frontmatter
create_invalid_skill() {
  local dir="${1:-$TEST_DIR}"
  local name="${2:-bad-skill}"
  mkdir -p "$dir/skills/$name"
  cat > "$dir/skills/$name/SKILL.md" << 'EOF'
---
name: bad-skill
---

Missing description and allowed-tools fields.
EOF
}

# Create isolated git repo for worktree tests
# Use pwd -P to resolve symlinks (macOS /var -> /private/var)
setup_git_repo() {
  TEST_DIR="$(cd "$(mktemp -d)" && pwd -P)"
  export TEST_DIR
  cd "$TEST_DIR" || exit

  # Clear git environment variables that pre-commit sets
  # These can interfere with worktree operations in isolated test repos
  unset GIT_INDEX_FILE
  unset GIT_DIR
  unset GIT_WORK_TREE

  git init
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "test" > file.txt
  git add file.txt
  git commit -m "Initial commit"
}

teardown_git_repo() {
  [[ -n "${TEST_DIR:-}" ]] && {
    cd /
    rm -rf "$TEST_DIR"
  }
}

# Create state file
create_state_file() {
  local dir="${1:-$TEST_DIR}"
  local current="${2:-1}"
  local total="${3:-5}"
  mkdir -p "$dir/.claude"
  cat > "$dir/.claude/dev-workflow-state.local.md" << EOF
---
workflow: swarm
plan: /path/to/plan.md
current_task: $current
total_tasks: $total
last_commit: $(git -C "$dir" rev-parse HEAD 2>/dev/null || echo "abc123")
---
EOF
}

# Create handoff file
create_handoff_file() {
  local dir="${1:-$TEST_DIR}"
  local mode="${2:-sequential}"
  mkdir -p "$dir/.claude"
  cat > "$dir/.claude/pending-handoff.local.md" << EOF
---
plan: /path/to/plan.md
mode: $mode
---
EOF
}

# Verify JSON validity
assert_valid_json() {
  # shellcheck disable=SC2154
  echo "$output" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null || {
    # shellcheck disable=SC2154
    echo "Invalid JSON: $output"
    return 1
  }
}
