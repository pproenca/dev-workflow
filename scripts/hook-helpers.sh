#!/bin/bash
# Minimal helper functions for hooks
# No external dependencies required

# Get absolute path to state file (worktree-scoped)
# Returns empty string if not in a git repository
get_state_file() {
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 0
  echo "${root}/.claude/dev-workflow-state.local.md"
}

# Get absolute path to handoff file (worktree-scoped)
# Returns empty string if not in a git repository
get_handoff_file() {
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 0
  echo "${root}/.claude/pending-handoff.local.md"
}

# Output JSON for hook response
output_json() {
  local msg="$1"
  # Escape special characters for JSON
  msg=$(echo "$msg" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
  echo "{\"hookSpecificOutput\": {\"hookEventName\": \"SessionStart\", \"additionalContext\": \"$msg\"}}"
}

# Check if state file exists
has_active_workflow() {
  [[ -f "$(get_state_file)" ]]
}

# Check if handoff is pending
has_pending_handoff() {
  [[ -f "$(get_handoff_file)" ]]
}

# Extract value from markdown frontmatter safely
# Usage: frontmatter_get <file> <key> [default]
# - Isolates frontmatter between --- markers (won't match keys in body)
# - Strips quotes from values
# - Returns default if key not found or value is empty/null
frontmatter_get() {
  local file="$1"
  local key="$2"
  local default="${3:-}"

  [[ -f "$file" ]] || { echo "$default"; return; }

  # Isolate frontmatter, then extract key
  local value
  value=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$file" | \
          grep "^${key}:" | head -1 | \
          sed "s/^${key}:[[:space:]]*//" | \
          sed 's/^"\(.*\)"$/\1/' | \
          sed "s/^'\(.*\)'$/\1/")

  # Return value or default
  if [[ -z "$value" ]] || [[ "$value" == "null" ]]; then
    echo "$default"
  else
    echo "$value"
  fi
}

# Update value in markdown frontmatter atomically
# Usage: frontmatter_set <file> <key> <value>
# - Uses temp file + mv pattern to prevent corruption
frontmatter_set() {
  local file="$1"
  local key="$2"
  local value="$3"
  local temp="${file}.tmp.$$"

  # Check if key exists
  if ! grep -q "^${key}:" "$file"; then
    echo "Error: Key '$key' not found in $file" >&2
    return 1
  fi

  # Escape special characters for sed replacement
  local escaped_value="${value//\\/\\\\}"
  escaped_value="${escaped_value//&/\\&}"

  # Use | delimiter to avoid conflicts with / in paths
  sed "s|^${key}: .*|${key}: ${escaped_value}|" "$file" > "$temp"
  mv "$temp" "$file"
}
