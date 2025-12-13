#!/usr/bin/env bash
# Worktree management utilities - simplified version
# No external dependencies (yq, jq) required

# Get repo root
get_repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || { echo "Not in git repo" >&2; return 1; }
}

# Get main worktree path
get_main_worktree() {
  git worktree list --porcelain | head -1 | cut -d' ' -f2-
}

# Check if in main repo (not a worktree)
is_main_repo() {
  local current main
  current="$(command cd "$(pwd)" && pwd -P)"
  main="$(command cd "$(get_main_worktree)" && pwd -P)"
  [[ "$current" == "$main" ]]
}

# Generate worktree name from plan file
generate_worktree_name() {
  local plan_file="$1"
  local base_name timestamp
  base_name="$(basename "$plan_file" .md)"
  timestamp="$(date +%Y%m%d-%H%M%S)"
  echo "${base_name}-${timestamp}"
}

# Create worktree at .worktrees/<name>
create_worktree() {
  local name="$1"
  local repo_root branch_name worktree_path

  repo_root="$(get_repo_root)"
  worktree_path="${repo_root}/.worktrees/${name}"
  branch_name="worktree/${name}"

  # Ensure .worktrees is gitignored
  if ! grep -q '^\.worktrees/$' "${repo_root}/.gitignore" 2>/dev/null; then
    echo ".worktrees/" >> "${repo_root}/.gitignore"
  fi

  mkdir -p "${repo_root}/.worktrees"
  git worktree add "$worktree_path" -b "$branch_name" HEAD >&2

  echo "$worktree_path"
}

# Create handoff state file - MINIMAL FORMAT
# Usage: create_handoff_state <plan_path> <worktree_path> <mode>
create_handoff_state() {
  local plan_file="$1"
  local worktree_path="$2"
  local exec_mode="${3:-sequential}"

  mkdir -p "${worktree_path}/.claude"

  # Minimal handoff state - just frontmatter
  cat > "${worktree_path}/.claude/pending-handoff.local.md" << EOF
---
plan: ${plan_file}
mode: ${exec_mode}
---
EOF

  echo "${worktree_path}/.claude/pending-handoff.local.md"
}

# List worktrees
list_worktrees() {
  local repo_root
  repo_root="$(get_repo_root)"

  if [[ -d "${repo_root}/.worktrees" ]]; then
    git worktree list | grep "\.worktrees/" || echo "No worktrees found"
  else
    echo "No worktrees found"
  fi
}

# Remove worktree
remove_worktree() {
  local target="$1"
  local repo_root worktree_path branch_name

  repo_root="$(get_repo_root)"

  if [[ "$target" != /* ]]; then
    worktree_path="${repo_root}/.worktrees/${target}"
  else
    worktree_path="$target"
  fi

  branch_name="$(git worktree list --porcelain | grep -A2 "^worktree ${worktree_path}$" | grep '^branch ' | cut -d' ' -f2- | sed 's|refs/heads/||' || echo '')"

  git worktree remove "$worktree_path" --force 2>/dev/null || rm -rf "$worktree_path"
  git worktree prune

  if [[ -n "$branch_name" ]]; then
    git branch -D "$branch_name" 2>/dev/null || true
  fi

  echo "Removed: $worktree_path"
}

# Cleanup all worktrees (interactive)
cleanup_all_worktrees() {
  local repo_root
  repo_root="$(get_repo_root)"

  if [[ ! -d "${repo_root}/.worktrees" ]]; then
    echo "No worktrees directory found"
    return 0
  fi

  echo "Worktrees to remove:"
  list_worktrees
  echo ""
  read -p "Remove all? (y/N) " -n 1 -r
  echo ""

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    for wt in "${repo_root}/.worktrees"/*/; do
      [[ -d "$wt" ]] && remove_worktree "$wt"
    done
    echo "All worktrees removed"
  else
    echo "Cancelled"
  fi
}

# Create worktree + handoff state in one call (DEPRECATED - use setup_worktree_with_state)
# Usage: setup_worktree_with_handoff <plan_file> [mode]
# Returns: worktree path
setup_worktree_with_handoff() {
  local plan_file="$1"
  local mode="${2:-pending}"

  local plan_abs worktree_name worktree_path
  plan_abs="$(realpath "$plan_file")"
  worktree_name="$(generate_worktree_name "$plan_file")"
  worktree_path="$(create_worktree "$worktree_name")"

  create_handoff_state "$plan_abs" "$worktree_path" "$mode"

  echo "$worktree_path"
}

# Create worktree + full state file in one call
# Usage: setup_worktree_with_state <plan_file> <workflow_type>
# workflow_type: "execute-plan" | "subagent"
# Returns: worktree path
# Outputs to stderr: STATE_FILE path
# Exits with error if plan has no tasks
setup_worktree_with_state() {
  local plan_file="$1"
  local workflow_type="${2:-execute-plan}"

  local plan_abs worktree_name worktree_path total_tasks base_sha state_file
  plan_abs="$(realpath "$plan_file")"

  # Validate plan has tasks before creating worktree
  total_tasks=$(grep -c "^### Task [0-9]\+:" "$plan_abs" 2>/dev/null || true)
  total_tasks="${total_tasks:-0}"
  if [[ "$total_tasks" -eq 0 ]]; then
    echo "ERROR: No tasks found in plan file: $plan_abs" >&2
    echo "Expected format: '### Task N: Description'" >&2
    return 1
  fi

  local repo_root main_repo_path
  repo_root="$(get_repo_root)"
  if is_main_repo; then
    base_sha=$(git rev-parse HEAD)
  else
    main_repo_path="$(get_main_worktree)"
    base_sha=$(cd "$main_repo_path" && git rev-parse HEAD)
  fi

  worktree_name="$(generate_worktree_name "$plan_file")"
  worktree_path="$(create_worktree "$worktree_name")"
  state_file="${worktree_path}/.claude/dev-workflow-state.local.md"

  mkdir -p "${worktree_path}/.claude"
  mkdir -p "${worktree_path}/.claude/task-outputs"
  touch "${worktree_path}/.claude/dev-workflow-progress.log"
  cat > "$state_file" << EOF
---
workflow: ${workflow_type}
worktree: ${worktree_path}
plan: ${plan_abs}
base_sha: ${base_sha}
current_task: 0
total_tasks: ${total_tasks}
last_commit: ${base_sha}
batch_size: 5
parallel_mode: true
retry_count: 0
failed_tasks: ""
enabled: true
---

Initialized from ${workflow_type}
EOF

  # Log initialization (cd to worktree for correct git root detection)
  # shellcheck source=scripts/hook-helpers.sh
  source "${BASH_SOURCE%/*}/hook-helpers.sh"
  (cd "$worktree_path" && log_progress "PLAN" "Initialized ${workflow_type} with ${total_tasks} tasks")

  # Output state file path to stderr for capture
  echo "STATE_FILE:${state_file}" >&2
  echo "TOTAL_TASKS:${total_tasks}" >&2

  # Return worktree path on stdout
  echo "$worktree_path"
}

# Find most recent pending worktree
# Returns: worktree path or empty
get_pending_worktree() {
  local repo_root
  repo_root="$(get_repo_root)"

  find "${repo_root}/.worktrees" -name "pending-handoff.local.md" -type f 2>/dev/null | \
    head -1 | \
    xargs -I{} dirname {} | \
    xargs -I{} dirname {}
}

# Update handoff mode atomically
# Usage: set_handoff_mode <worktree_path> <mode>
set_handoff_mode() {
  local worktree="$1"
  local mode="$2"
  local handoff_file="${worktree}/.claude/pending-handoff.local.md"
  local temp="${handoff_file}.tmp.$$"

  sed "s/^mode: .*/mode: $mode/" "$handoff_file" > "$temp"
  mv "$temp" "$handoff_file"
}

# Activate worktree for execution - sets mode and returns path
# Usage: activate_worktree <mode>
activate_worktree() {
  local mode="$1"
  local worktree
  worktree="$(get_pending_worktree)"

  if [[ -n "$worktree" ]]; then
    set_handoff_mode "$worktree" "$mode"
    echo "$worktree"
  fi
}

# Main entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-help}" in
    create) create_worktree "$2" ;;
    remove) remove_worktree "$2" ;;
    list) list_worktrees ;;
    is-main) is_main_repo && echo "true" || echo "false" ;;
    handoff) create_handoff_state "$2" "$3" "$4" ;;
    cleanup) cleanup_all_worktrees ;;
    setup) setup_worktree_with_handoff "$2" "$3" ;;
    setup-state) setup_worktree_with_state "$2" "$3" ;;
    pending) get_pending_worktree ;;
    activate) activate_worktree "$2" ;;
    set-mode) set_handoff_mode "$2" "$3" ;;
    *)
      echo "Usage: $0 {create|remove|list|is-main|setup-state|cleanup|...} [args]"
      echo ""
      echo "Commands:"
      echo "  create <name>                    Create worktree at .worktrees/<name>"
      echo "  remove <name>                    Remove worktree by name or path"
      echo "  list                             List all .worktrees/"
      echo "  is-main                          Check if in main repo"
      echo "  setup-state <plan> <workflow>    Create worktree + state file (preferred)"
      echo "  setup <plan> [mode]              Create worktree + handoff (deprecated)"
      echo "  cleanup                          Remove all worktrees (interactive)"
      echo "  pending                          Get most recent pending worktree"
      echo "  activate <mode>                  Set mode and return pending worktree path"
      echo "  set-mode <wt_path> <mode>        Update handoff mode"
      ;;
  esac
fi
