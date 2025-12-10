#!/usr/bin/env bash
# Validate bash syntax in command markdown files
# Extracts !` inline blocks and ```bash code blocks, runs bash -n

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ERRORS=0
CHECKED=0

err() { echo "[ERR] $1"; ERRORS=$((ERRORS + 1)); }
ok() { echo "[OK] $1"; }

# Extract and validate bash from a command file
validate_file() {
  local file="$1"
  local name
  name=$(basename "$file" .md)
  local file_errors=0
  local block_num=0

  # Create temp file for bash extraction
  local tmpfile
  tmpfile=$(mktemp)
  # shellcheck disable=SC2064 # Intentional: capture $tmpfile now, not at signal time
  trap "rm -f '$tmpfile'" RETURN

  # Extract !` inline blocks (handles both !`cmd` and !`multi-line`)
  # shellcheck disable=SC2016 # Single quotes intentional: matching literal backticks
  while IFS= read -r line_content; do
    block_num=$((block_num + 1))
    echo "$line_content" > "$tmpfile"
    if ! bash -n "$tmpfile" 2>/dev/null; then
      err "$name: inline block #$block_num syntax error"
      echo "    Content: ${line_content:0:60}..."
      file_errors=$((file_errors + 1))
    fi
  done < <(grep -oE '!\`[^\`]+\`' "$file" 2>/dev/null | sed 's/^!\`//;s/\`$//' || true)

  # Extract ```bash code blocks
  local in_block=false
  local block_content=""
  local block_start_line=0
  local line_num=0

  while IFS= read -r line; do
    line_num=$((line_num + 1))

    if [[ "$line" =~ ^\`\`\`bash ]]; then
      in_block=true
      block_content=""
      block_start_line=$line_num
      continue
    fi

    if [[ "$line" =~ ^\`\`\` ]] && [[ "$in_block" == true ]]; then
      in_block=false
      block_num=$((block_num + 1))

      # Skip empty blocks
      if [[ -z "${block_content// }" ]]; then
        continue
      fi

      echo "$block_content" > "$tmpfile"
      if ! bash -n "$tmpfile" 2>/dev/null; then
        err "$name: bash block at line $block_start_line syntax error"
        # Show first line of block for context
        first_line=$(echo "$block_content" | head -1)
        echo "    First line: ${first_line:0:60}"
        file_errors=$((file_errors + 1))
      fi
      continue
    fi

    if [[ "$in_block" == true ]]; then
      block_content+="$line"$'\n'
    fi
  done < "$file"

  CHECKED=$((CHECKED + block_num))

  if [[ $file_errors -eq 0 ]]; then
    ok "$name ($block_num blocks)"
  fi

  return $file_errors
}

echo "=== Validating bash syntax in commands ==="

for f in "$PLUGIN_ROOT"/commands/*.md; do
  [[ -f "$f" ]] || continue
  validate_file "$f" || true
done

echo ""
echo "=== Result: Checked $CHECKED blocks, $([[ $ERRORS -eq 0 ]] && echo "PASS" || echo "FAIL ($ERRORS errors)") ==="

exit $ERRORS
