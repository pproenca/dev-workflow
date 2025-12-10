#!/usr/bin/env bash
# Opens a new Terminal.app window in the specified directory and runs claude

WORKTREE_PATH="$1"

if [[ -z "$WORKTREE_PATH" ]]; then
  echo "Usage: $0 <worktree-path>" >&2
  exit 1
fi

if [[ ! -d "$WORKTREE_PATH" ]]; then
  echo "Error: Directory does not exist: $WORKTREE_PATH" >&2
  exit 1
fi

osascript <<EOF
tell application "Terminal"
    activate
    do script "cd '$WORKTREE_PATH' && claude --dangerously-skip-permissions"
end tell
EOF

echo "Launched Terminal.app in: $WORKTREE_PATH"
