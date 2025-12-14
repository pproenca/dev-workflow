#!/usr/bin/env bash
# Worktree management utilities
# No external dependencies required

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

# Generate worktree name from description
generate_worktree_name() {
  local description="$1"
  local base_name timestamp
  base_name="$(echo "$description" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g' | cut -c1-30)"
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

# Main entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-help}" in
    create) create_worktree "$2" ;;
    remove) remove_worktree "$2" ;;
    list) list_worktrees ;;
    is-main) is_main_repo && echo "true" || echo "false" ;;
    cleanup) cleanup_all_worktrees ;;
    *)
      echo "Usage: $0 {create|remove|list|is-main|cleanup} [args]"
      echo ""
      echo "Commands:"
      echo "  create <name>    Create worktree at .worktrees/<name>"
      echo "  remove <name>    Remove worktree by name or path"
      echo "  list             List all .worktrees/"
      echo "  is-main          Check if in main repo"
      echo "  cleanup          Remove all worktrees (interactive)"
      ;;
  esac
fi
