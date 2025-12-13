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
  escaped_value="${escaped_value//|/\\|}"
  escaped_value="${escaped_value//&/\\&}"

  # Use | delimiter to avoid conflicts with / in paths
  sed "s|^${key}: .*|${key}: ${escaped_value}|" "$file" > "$temp"
  mv "$temp" "$file"
}

# ============================================================================
# Progress Log Functions (Anthropic Multi-Agent Pattern)
# ============================================================================

# Get path to progress log file
get_progress_log() {
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 0
  echo "${root}/.claude/dev-workflow-progress.log"
}

# Log an event to the progress log
# Usage: log_progress <event_type> <message>
# Event types: PLAN, GROUP_START, GROUP_COMPLETE, TASK_START, TASK_COMPLETE, PHASE_SUMMARY, ERROR, RESUME
log_progress() {
  local event_type="$1"
  local message="$2"
  local log_file
  log_file="$(get_progress_log)"

  [[ -z "$log_file" ]] && return 1

  # Ensure directory exists
  mkdir -p "$(dirname "$log_file")"

  # Append timestamped entry
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ${event_type}: ${message}" >> "$log_file"
}

# Read recent progress entries (for session resume)
# Usage: get_recent_progress [count]
get_recent_progress() {
  local count="${1:-10}"
  local log_file
  log_file="$(get_progress_log)"

  [[ -f "$log_file" ]] || { echo "No progress log found"; return; }

  tail -n "$count" "$log_file"
}

# Get last phase summary (for context on resume)
get_last_phase_summary() {
  local log_file
  log_file="$(get_progress_log)"

  [[ -f "$log_file" ]] || return

  grep "PHASE_SUMMARY:" "$log_file" | tail -1 | sed 's/.*PHASE_SUMMARY: //'
}

# ============================================================================
# Task Output Functions (Lightweight Reference Pattern)
# ============================================================================

# Get path to task outputs directory
get_task_outputs_dir() {
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 0
  echo "${root}/.claude/task-outputs"
}

# Create task output file and return path
# Usage: create_task_output <task_num>
create_task_output_path() {
  local task_num="$1"
  local outputs_dir
  outputs_dir="$(get_task_outputs_dir)"

  mkdir -p "$outputs_dir"
  echo "${outputs_dir}/task-${task_num}.md"
}

# ============================================================================
# Dependency Analysis Functions
# ============================================================================

# Extract files from a task section
# Usage: get_task_files <plan_file> <task_num>
get_task_files() {
  local plan_file="$1"
  local task_num="$2"
  local next_task=$((task_num + 1))

  # shellcheck disable=SC2016 # Backtick regex is intentional
  awk "/^### Task ${task_num}:/,/^### Task ${next_task}:|^## /" "$plan_file" | \
    grep -E '(Create|Modify|Test):' | \
    grep -oE '`[^`]+`' | tr -d '`' | sort -u
}

# Check if two tasks have file overlap (dependency)
# Usage: tasks_overlap <plan_file> <task1> <task2>
# Returns: 0 if overlap, 1 if no overlap
tasks_overlap() {
  local plan_file="$1"
  local task1="$2"
  local task2="$3"

  local files1 files2
  files1=$(get_task_files "$plan_file" "$task1")
  files2=$(get_task_files "$plan_file" "$task2")

  # Check for any common files
  local common
  common=$(comm -12 <(echo "$files1" | sort) <(echo "$files2" | sort))

  [[ -n "$common" ]]
}

# Group tasks by dependencies (returns JSON-like structure)
# Usage: group_tasks_by_dependency <plan_file> <total_tasks> [max_group_size]
# Output: group1:1,2,3|group2:4,5|group3:6,7,8,9
group_tasks_by_dependency() {
  local plan_file="$1"
  local total_tasks="$2"
  local max_group="${3:-5}"  # Default max 5 per group (Anthropic pattern)

  local groups=""
  local current_group=""
  local current_group_files=""
  local group_count=0
  local group_num=1

  for ((i=1; i<=total_tasks; i++)); do
    local task_files
    task_files=$(get_task_files "$plan_file" "$i")

    # Check if task overlaps with current group
    local has_overlap=false
    if [[ -n "$current_group_files" ]] && [[ -n "$task_files" ]]; then
      local common
      common=$(comm -12 <(echo "$current_group_files" | sort) <(echo "$task_files" | sort) 2>/dev/null)
      [[ -n "$common" ]] && has_overlap=true
    fi

    # Start new group if: overlap, or group full
    if [[ "$has_overlap" == "true" ]] || [[ "$group_count" -ge "$max_group" ]]; then
      # Save current group
      if [[ -n "$current_group" ]]; then
        [[ -n "$groups" ]] && groups="${groups}|"
        groups="${groups}group${group_num}:${current_group}"
        ((group_num++))
      fi
      # Start new group with this task
      current_group="$i"
      current_group_files="$task_files"
      group_count=1
    else
      # Add to current group
      [[ -n "$current_group" ]] && current_group="${current_group},$i" || current_group="$i"
      current_group_files="${current_group_files}"$'\n'"${task_files}"
      ((group_count++))
    fi
  done

  # Save last group
  if [[ -n "$current_group" ]]; then
    [[ -n "$groups" ]] && groups="${groups}|"
    groups="${groups}group${group_num}:${current_group}"
  fi

  echo "$groups"
}

# ============================================================================
# Ephemeral Worktree Detection Functions
# ============================================================================

# Check if current directory is in an ephemeral worktree
# Usage: is_ephemeral_worktree
# Returns: 0 if in ephemeral worktree, 1 otherwise
is_ephemeral_worktree() {
  local current_path
  current_path="$(pwd -P)"
  [[ "$current_path" == *"/.worktrees/.ephemeral/"* ]]
}

# Get main repo path from ephemeral worktree path
# Usage: get_main_from_ephemeral
# Returns: main repo path (not execution worktree) or empty if not in ephemeral
get_main_from_ephemeral() {
  local current_path
  current_path="$(pwd -P)"

  if [[ "$current_path" == *"/.worktrees/.ephemeral/"* ]]; then
    # Extract path before /.worktrees/.ephemeral/
    echo "${current_path%%/.worktrees/.ephemeral/*}"
  fi
}

# Get execution worktree path from ephemeral worktree
# Usage: get_execution_worktree_from_ephemeral
# Returns: first non-ephemeral worktree in .worktrees/ or empty
# Note: This finds the "main" execution worktree (not ephemeral) for output files
get_execution_worktree_from_ephemeral() {
  local main_repo
  main_repo="$(get_main_from_ephemeral)"

  [[ -z "$main_repo" ]] && return

  # Find the first non-ephemeral worktree (the execution worktree)
  find "${main_repo}/.worktrees" -maxdepth 1 -type d -name "*-[0-9]*" ! -name ".ephemeral" 2>/dev/null | head -1
}
