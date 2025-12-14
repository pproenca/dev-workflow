---
description: Create detailed implementation plan saved to docs/plans/
argument-hint: [feature] or [@design-doc.md]
allowed-tools: Read, Write, Grep, Glob, Bash, TodoWrite, AskUserQuestion, Task
---

# Write Implementation Plan

Create TDD implementation plan by exploring codebase, resolving ambiguities, and producing executable task list.

## Input

$ARGUMENTS

**If empty:** Use AskUserQuestion to ask what feature to plan.

**If @file referenced:** Read it, use as context.

## Step 1: Explore Codebase

Dispatch code-explorer to survey the codebase:

```claude
Task:
  subagent_type: dev-workflow:code-explorer
  description: "Explore codebase"
  prompt: |
    Survey codebase for [feature]:
    1. Similar features - existing implementations to reference
    2. Integration points - boundaries and dependencies
    3. Testing patterns - conventions and test file locations

    Report 10-15 essential files. Limit to 10 tool calls.
```

After return: Note patterns for Step 3.

## Step 2: Clarify Ambiguities

**Skip if:** Design doc from `/dev-workflow:brainstorm` exists AND is comprehensive.

Identify underspecified aspects:

- Edge cases and error handling
- Integration points
- Scope boundaries

Present using AskUserQuestion (one question at a time, 2-4 options each).

**Wait for answers before Step 3.**

## Step 3: Design Architecture

For complex features (5+ files), dispatch code-architect:

```claude
Task:
  subagent_type: dev-workflow:code-architect
  description: "Design architecture"
  prompt: |
    Design architecture for [feature] using exploration context.

    Present 2 approaches:
    1. Minimal changes - smallest diff, maximum reuse
    2. Clean architecture - best maintainability

    For each: key files, components, trade-offs.
    Recommend one.
```

Use AskUserQuestion to confirm approach.

## Step 4: Write Plan

**CRITICAL:** Save to `docs/plans/YYYY-MM-DD-<feature-name>.md`, NOT to `.claude/plans/`.

### Header

```markdown
# [Feature Name] Implementation Plan

**Goal:** [One sentence]

**Architecture:** [2-3 sentences from Step 3]

---
```

### Task Structure

Each task MUST be self-contained with explicit TDD instructions:

````markdown
### Task N: [Component Name]

**Effort:** simple (3-10 tool calls) | standard (10-15) | complex (15-25)

**Files:**
- Create: `exact/path/to/new.py`
- Modify: `exact/path/to/existing.py:50-75`
- Test: `tests/exact/path/test.py`

**TDD Instructions (MANDATORY):**

1. **Write test FIRST:**
   ```python
   def test_behavior():
       result = function(input)
       assert result == expected
   ```

2. **Run test, verify FAILURE:**
   ```bash
   pytest tests/path -v
   ```

3. **Implement MINIMAL code**

4. **Run test, verify PASS**

5. **Commit:**
   ```bash
   git add -A && git commit -m "feat(scope): description"
   ```
````

### Parallel Groups

Tasks with NO file overlap execute in parallel (3-5 per group):

| Task Group | Tasks | Rationale |
|------------|-------|-----------|
| Group 1 | 1, 2, 3 | Independent modules, no file overlap |
| Group 2 | 4, 5 | Both touch shared types, must be serial |
| Group 3 | 6, 7, 8 | Independent tests, no file overlap |

### Final Task

Always include "Code Review" as the final task.

### Save and Commit

```bash
mkdir -p docs/plans
# Write plan content to docs/plans/YYYY-MM-DD-<feature>.md
git add docs/plans/
git commit -m "docs: implementation plan for <feature>"
```

## Step 5: Execution Handoff

Use AskUserQuestion:

```claude
AskUserQuestion:
  header: "Execute"
  question: "Plan saved. How to proceed?"
  multiSelect: false
  options:
    - label: "Execute now"
      description: "Run /dev-workflow:execute-plan immediately"
    - label: "Later"
      description: "Execute manually when ready"
    - label: "Revise plan"
      description: "Adjust the plan first"
```

**If "Execute now":**

```text
/dev-workflow:execute-plan docs/plans/[filename].md
```

**If "Later":**

Report the plan file path for manual execution.

**If "Revise plan":**

Wait for feedback, update plan, return to Step 5.
