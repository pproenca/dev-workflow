#!/bin/bash
# Validate all skill/command/agent references use plugin prefix

set -euo pipefail

PLUGIN_NAME="dev-workflow"
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ERRORS=0

echo "=== Validating plugin name prefixes ==="
echo

# 1. Extract all skill names
echo "--- Skills ---"
SKILLS=()
for skill_dir in "$PLUGIN_ROOT"/skills/*/; do
  if [[ -f "${skill_dir}SKILL.md" ]]; then
    name=$(grep -E "^name:" "${skill_dir}SKILL.md" | head -1 | sed 's/name:[[:space:]]*//')
    SKILLS+=("$name")
    echo "[OK] $name"
  fi
done

# 2. Extract all agent names
echo
echo "--- Agents ---"
AGENTS=()
for agent_file in "$PLUGIN_ROOT"/agents/*.md; do
  if [[ -f "$agent_file" ]]; then
    name=$(grep -E "^name:" "$agent_file" | head -1 | sed 's/name:[[:space:]]*//')
    AGENTS+=("$name")
    echo "[OK] $name"
  fi
done

# 3. Check for unprefixed Skill() calls
echo
echo "--- Checking Skill() references ---"
# Find Skill("X") where X does not start with plugin name
while IFS= read -r line; do
  file=$(echo "$line" | cut -d: -f1)
  match=$(echo "$line" | grep -oE 'Skill\("[^"]+"\)' || true)
  if [[ -n "$match" ]]; then
    skill_ref=$(echo "$match" | sed 's/Skill("//;s/")//')
    if [[ ! "$skill_ref" =~ ^${PLUGIN_NAME}: ]]; then
      echo "[ERROR] $file: $match (missing prefix)"
      ((ERRORS++))
    fi
  fi
done < <(grep -rn 'Skill("' "$PLUGIN_ROOT" --include="*.md" 2>/dev/null || true)

if [[ $ERRORS -eq 0 ]]; then
  echo "[OK] All Skill() references use prefix"
fi

# 4. Check for unprefixed Task tool agent references
echo
echo "--- Checking Task tool agent references ---"
for agent in "${AGENTS[@]}"; do
  # Find references to agent without prefix
  unprefixed=$(grep -rn "subagent_type.*['\"]${agent}['\"]" "$PLUGIN_ROOT" --include="*.md" 2>/dev/null || true)
  if [[ -n "$unprefixed" ]]; then
    echo "[ERROR] Unprefixed agent reference: $agent"
    echo "$unprefixed"
    ((ERRORS++))
  fi

  # Find references like "Task tool (agent-name)" without prefix
  unprefixed2=$(grep -rn "Task tool (${agent})" "$PLUGIN_ROOT" --include="*.md" 2>/dev/null || true)
  if [[ -n "$unprefixed2" ]]; then
    echo "[ERROR] Unprefixed Task tool reference: $agent"
    echo "$unprefixed2"
    ((ERRORS++))
  fi
done

if [[ $ERRORS -eq 0 ]]; then
  echo "[OK] All Task tool references use prefix"
fi

# 5. Check for unprefixed skills in agent frontmatter
echo
echo "--- Checking agent skills frontmatter ---"
SKILL_ERRORS=0
for agent_file in "$PLUGIN_ROOT"/agents/*.md; do
  [[ -f "$agent_file" ]] || continue
  agent_name=$(basename "$agent_file" .md)

  # Extract skills: line from frontmatter
  skills_line=$(grep "^skills:" "$agent_file" 2>/dev/null | head -1 | sed 's/skills:[[:space:]]*//' || true)
  [[ -z "$skills_line" ]] && continue

  # Check each skill in the comma-separated list
  IFS=',' read -ra skill_list <<< "$skills_line"
  for skill in "${skill_list[@]}"; do
    skill=$(echo "$skill" | xargs)  # trim whitespace
    [[ -z "$skill" ]] && continue
    if [[ ! "$skill" =~ ^${PLUGIN_NAME}: ]]; then
      echo "[ERROR] $agent_name: skill '$skill' missing prefix (should be ${PLUGIN_NAME}:$skill)"
      ((SKILL_ERRORS++))
    fi
  done
done
ERRORS=$((ERRORS + SKILL_ERRORS))

if [[ $SKILL_ERRORS -eq 0 ]]; then
  echo "[OK] All agent skills use prefix"
fi

# 6. Extract command names and check for unprefixed references
echo
echo "--- Commands ---"
COMMANDS=()
for cmd_file in "$PLUGIN_ROOT"/commands/*.md; do
  if [[ -f "$cmd_file" ]]; then
    name=$(basename "$cmd_file" .md)
    COMMANDS+=("$name")
    echo "[OK] $name"
  fi
done

echo
echo "--- Checking slash command references ---"
CMD_ERRORS=0
for cmd in "${COMMANDS[@]}"; do
  # Find /command references (with space/backtick before, and space/backtick/paren/newline after)
  while IFS= read -r line; do
    # Skip if already has the prefix
    if echo "$line" | grep -q "/${PLUGIN_NAME}:${cmd}"; then
      continue
    fi
    # Skip if this is a file path (.yaml, .md, .sh extensions)
    if echo "$line" | grep -qE "/${cmd}\.(yaml|md|sh)"; then
      continue
    fi
    file=$(echo "$line" | cut -d: -f1)
    # Skip docs/plans (historical plans)
    if [[ "$file" == *"docs/plans"* ]]; then
      continue
    fi
    # Skip the command's own definition file
    if [[ "$file" == *"commands/${cmd}.md"* ]]; then
      continue
    fi
    echo "[ERROR] $file: /${cmd} (should be /${PLUGIN_NAME}:${cmd})"
    ((CMD_ERRORS++))
  done < <(grep -rn -E "(^|[[:space:]\`])/${cmd}([[:space:]\`\)\"]|$)" "$PLUGIN_ROOT" --include="*.md" --include="*.sh" 2>/dev/null || true)
done
ERRORS=$((ERRORS + CMD_ERRORS))

if [[ $CMD_ERRORS -eq 0 ]]; then
  echo "[OK] All slash command references use prefix"
fi

# 8. Check for unprefixed skill names in documentation
echo
echo "--- Checking skill references in documentation ---"
DOC_ERRORS=0
for skill in "${SKILLS[@]}"; do
  # Search for skill name in references/ that isn't prefixed
  while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    # Skip skill's own definition file
    if [[ "$file" == *"skills/${skill}/SKILL.md"* ]]; then
      continue
    fi
    # Skip if this occurrence is already prefixed
    if echo "$line" | grep -q "${PLUGIN_NAME}:${skill}"; then
      continue
    fi
    linenum=$(echo "$line" | cut -d: -f2)
    echo "[ERROR] $file:$linenum: '$skill' (should be ${PLUGIN_NAME}:$skill)"
    ((DOC_ERRORS++))
  done < <(grep -rn -E "(^|[^:a-z-])${skill}([^a-z-]|$)" "$PLUGIN_ROOT/references" --include="*.md" 2>/dev/null || true)
done

ERRORS=$((ERRORS + DOC_ERRORS))

if [[ $DOC_ERRORS -eq 0 ]]; then
  echo "[OK] All documentation skill references use prefix"
fi

# 9. Summary
echo
echo "=== Result: $([ $ERRORS -eq 0 ] && echo "PASS" || echo "FAIL ($ERRORS errors)") ==="
exit $ERRORS
