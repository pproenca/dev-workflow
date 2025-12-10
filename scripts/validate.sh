#!/usr/bin/env bash
# Plugin validation - run before releases or when things break
# Usage: ./scripts/validate.sh

# SC2015: A && B || C pattern is safe here - ok/err are echo functions that won't fail
# shellcheck disable=SC2015

set -euo pipefail
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ERRORS=0

err() { echo "[ERR] $1"; ERRORS=$((ERRORS + 1)); }
ok() { echo "[OK] $1"; }
warn() { echo "[WARN] $1"; }

echo "=== Validating dev-workflow plugin ==="

# Dependencies
echo -e "\n--- Dependencies ---"
command -v git &>/dev/null && ok "git" || err "git missing"

# JSON syntax
echo -e "\n--- JSON Files ---"
for f in "$PLUGIN_ROOT"/.claude-plugin/*.json "$PLUGIN_ROOT"/hooks/*.json; do
  [[ -f "$f" ]] || continue
  if command -v jq &>/dev/null; then
    jq empty "$f" 2>/dev/null && ok "$(basename "$f")" || err "$(basename "$f") invalid JSON"
  else
    ok "$(basename "$f") (jq not available, skipped)"
  fi
done

# Script permissions
echo -e "\n--- Scripts ---"
for f in "$PLUGIN_ROOT"/hooks/*.sh "$PLUGIN_ROOT"/scripts/*.sh; do
  [[ -f "$f" ]] || continue
  [[ -x "$f" ]] && ok "$(basename "$f") executable" || err "$(basename "$f") not executable"
done

# Skills have required fields
echo -e "\n--- Skills ---"
for f in "$PLUGIN_ROOT"/skills/*/SKILL.md; do
  name=$(basename "$(dirname "$f")")
  if grep -q "^name:" "$f" && grep -q "^description:" "$f" && grep -q "^allowed-tools:" "$f"; then
    ok "$name"
  else
    err "$name missing frontmatter fields"
  fi
done

# Commands have required fields
echo -e "\n--- Commands ---"
for f in "$PLUGIN_ROOT"/commands/*.md; do
  name=$(basename "$f" .md)
  if grep -q "^description:" "$f" && grep -q "^allowed-tools:" "$f"; then
    ok "$name"
  else
    err "$name missing frontmatter fields"
  fi
done

# Plugin name prefixes
echo -e "\n--- Prefixes ---"
if "$PLUGIN_ROOT/scripts/validate-prefixes.sh" >/dev/null 2>&1; then
  ok "All references use dev-workflow: prefix"
else
  err "Some references missing plugin prefix (run ./scripts/validate-prefixes.sh for details)"
fi

# Bash syntax in commands
echo -e "\n--- Bash Syntax ---"
if "$PLUGIN_ROOT/scripts/validate-bash-in-commands.sh" >/dev/null 2>&1; then
  ok "All bash blocks have valid syntax"
else
  err "Invalid bash syntax in commands (run ./scripts/validate-bash-in-commands.sh for details)"
fi

# Shellcheck
echo -e "\n--- Shellcheck ---"
if command -v shellcheck &>/dev/null; then
  shellcheck_failed=0
  for f in "$PLUGIN_ROOT"/hooks/*.sh "$PLUGIN_ROOT"/scripts/*.sh; do
    [[ -f "$f" ]] || continue
    # -x follows source statements to check sourced files
    if shellcheck -x "$f" >/dev/null 2>&1; then
      ok "$(basename "$f")"
    else
      err "$(basename "$f") has shellcheck warnings"
      shellcheck_failed=1
    fi
  done
  if [[ $shellcheck_failed -ne 0 ]]; then
    warn "Run 'shellcheck -x <file>' for details"
  fi
else
  warn "shellcheck not installed, skipping"
fi

# Frontmatter value validation
echo -e "\n--- Frontmatter Values ---"
VALID_TOOLS="Read|Write|Edit|Bash|Glob|Grep|Task|TodoWrite|AskUserQuestion|Skill|WebFetch|WebSearch|NotebookRead|NotebookEdit|LS"
for f in "$PLUGIN_ROOT"/commands/*.md "$PLUGIN_ROOT"/skills/*/SKILL.md "$PLUGIN_ROOT"/agents/*.md; do
  [[ -f "$f" ]] || continue
  name=$(basename "$f" .md)
  [[ "$name" == "SKILL" ]] && name=$(basename "$(dirname "$f")")

  # Check allowed-tools/tools contains only valid tools (agents use 'tools:', others use 'allowed-tools:')
  tools_line=$(grep -E "^(allowed-tools|tools):" "$f" 2>/dev/null | head -1 | sed 's/^[a-z-]*:[[:space:]]*//')
  if [[ -n "$tools_line" ]]; then
    # Normalize: handle both JSON array ["A", "B"] and comma-separated "A, B" formats
    normalized=$(echo "$tools_line" | sed 's/\[//g; s/\]//g; s/"//g; s/,/ /g')
    invalid_tools=""
    for tool in $normalized; do
      tool=$(echo "$tool" | xargs)  # trim whitespace
      [[ -z "$tool" ]] && continue
      if [[ ! "$tool" =~ ^($VALID_TOOLS)$ ]]; then
        invalid_tools+="$tool "
      fi
    done
    if [[ -n "$invalid_tools" ]]; then
      err "$name has invalid tools: $invalid_tools"
    fi
  fi

  # Check description is not empty
  desc_line=$(grep "^description:" "$f" 2>/dev/null | head -1 | sed 's/description:[[:space:]]*//')
  if [[ -z "$desc_line" ]]; then
    err "$name has empty description"
  fi
done
ok "Frontmatter values validated"

# Summary
echo -e "\n=== Result: $([[ $ERRORS -eq 0 ]] && echo "PASS" || echo "FAIL ($ERRORS errors)") ==="
exit $ERRORS
