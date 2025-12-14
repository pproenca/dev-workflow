#!/bin/bash
# Minimal helper functions for hooks and scripts
# No external dependencies required

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

# Get state file path (repo-scoped)
# Usage: get_state_file
# Returns: Path to .claude/dev-workflow-state.local.md in repo root
# Exit 1 if not in a git repo
get_state_file() {
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
  echo "${repo_root}/.claude/dev-workflow-state.local.md"
}

# Create minimal state file for workflow resume
# Usage: create_state_file <plan_file>
# Creates: .claude/dev-workflow-state.local.md with plan, current_task, total_tasks, base_sha
create_state_file() {
  local plan_file="$1"
  local state_file
  state_file=$(get_state_file) || return 1

  local total_tasks
  total_tasks=$(grep -c "^### Task [0-9]\+:" "$plan_file" 2>/dev/null || echo "0")

  mkdir -p "$(dirname "$state_file")"
  cat > "$state_file" << EOF
---
plan: $plan_file
current_task: 0
total_tasks: $total_tasks
base_sha: $(git rev-parse HEAD)
---
EOF
}

# Delete state file (workflow complete or abandoned)
# Usage: delete_state_file
delete_state_file() {
  local state_file
  state_file=$(get_state_file) || return 1
  rm -f "$state_file"
}

# Extract file paths from a task section
# Usage: get_task_files <plan_file> <task_num>
# Returns: List of file paths (one per line)
get_task_files() {
  local plan_file="$1"
  local task_num="$2"
  local next_task=$((task_num + 1))

  # Extract task section and find file paths in backticks after Create/Modify/Test:
  # shellcheck disable=SC2016 # Backtick regex is intentional - matching literal backticks
  awk "/^### Task ${task_num}:/,/^### Task ${next_task}:|^## /" "$plan_file" | \
    grep -E '(Create|Modify|Test):' | \
    grep -oE '`[^`]+`' | tr -d '`' | sort -u
}

# Group tasks by file dependencies for parallel execution
# Usage: group_tasks_by_dependency <plan_file> <total_tasks> [max_group_size]
# Output: group1:1,2,3|group2:4,5|group3:6,7,8,9
# Tasks within a group have NO file overlap (can run in parallel)
# Groups execute serially (group 1 completes before group 2)
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
        group_num=$((group_num + 1))
      fi
      # Start new group with this task
      current_group="$i"
      current_group_files="$task_files"
      group_count=1
    else
      # Add to current group
      [[ -n "$current_group" ]] && current_group="${current_group},$i" || current_group="$i"
      current_group_files="${current_group_files}"$'\n'"${task_files}"
      group_count=$((group_count + 1))
    fi
  done

  # Save last group
  if [[ -n "$current_group" ]]; then
    [[ -n "$groups" ]] && groups="${groups}|"
    groups="${groups}group${group_num}:${current_group}"
  fi

  echo "$groups"
}

# Get maximum parallelism from task groups
# Usage: get_max_parallel_from_groups <groups_string>
# Input: "group1:1,2,3|group2:4,5|group3:6"
# Output: 3 (largest group has 3 tasks)
get_max_parallel_from_groups() {
  local groups="$1"
  local max_parallel=1

  # Split by | and find largest group
  IFS='|' read -ra GROUP_ARRAY <<< "$groups"
  for group in "${GROUP_ARRAY[@]}"; do
    # Extract task list after colon
    local task_list="${group#*:}"
    # Count tasks (comma-separated)
    local task_count
    task_count=$(echo "$task_list" | tr ',' '\n' | wc -l | tr -d ' ')
    if [[ "$task_count" -gt "$max_parallel" ]]; then
      max_parallel="$task_count"
    fi
  done

  echo "$max_parallel"
}

# Extract task section content from plan
# Usage: get_task_content <plan_file> <task_num>
# Returns: Full task section including TDD instructions
get_task_content() {
  local plan_file="$1"
  local task_num="$2"
  local next_task=$((task_num + 1))

  # Extract from "### Task N:" to next task or end of section
  awk "/^### Task ${task_num}:/,/^### Task ${next_task}:|^## [^#]/" "$plan_file" | \
    sed '/^### Task '"${next_task}"':/d' | \
    sed '/^## [^#]/d'
}
