---
description: Create detailed implementation plan with codebase understanding
argument-hint: [feature] or [@design-doc.md]
allowed-tools: ["Read", "Write", "Grep", "Glob", "Bash", "TodoWrite", "AskUserQuestion", "Skill", "Task"]
---

# Write Implementation Plan

Create TDD implementation plan by exploring codebase, resolving ambiguities, designing architecture, and producing executable task list.

## Input

$ARGUMENTS

**If empty or no arguments:** Use AskUserQuestion to ask what feature to plan.

**If @file referenced:** Check if file exists using Read tool. If file not found, stop with error.

## Concurrency

This command creates a plan file, not a state file. Multiple terminals can run `/dev-workflow:write-plan` simultaneously without conflict. State files are only created during execution.

For parallel executions of the same plan, each must be in a separate worktree. Worktrees are created automatically by `/dev-workflow:execute-plan`.

## Step 1: Understand Request

**If `@docs/plans/*-design.md` provided:** Read it, use as context, skip to Step 2.

**If feature description provided:** Confirm understanding using AskUserQuestion:

```claude
AskUserQuestion:
  header: "Scope"
  question: "Building [restatement]. Correct?"
  multiSelect: false
  options:
    - label: "Yes"
      description: "Proceed with this understanding"
    - label: "Clarify"
      description: "Adjust scope before proceeding"
```

**If unclear:** Ask what problem to solve, what functionality, what constraints.

## Step 2: Explore Codebase

Dispatch code-explorer using Task tool:

```claude
Task tool (dev-workflow:code-explorer):
  prompt: |
    Survey codebase for [feature]:
    1. Similar features - existing implementations to reference
    2. Integration points - boundaries and dependencies
    3. Testing patterns - conventions and test file locations

    Report 10-15 essential files. Limit to 10 tool calls.
```

After return: Read essential files. Note patterns for Step 4.

Use TodoWrite to create items for: Steps 2-5 + "Save Plan" + "Execution Handoff".

## Step 3: Clarify Ambiguities

**Skip if:** Design doc from `/dev-workflow:brainstorm` exists AND covers: edge cases, integration points, scope boundaries.

Identify underspecified aspects:

- Edge cases and error handling
- Integration points
- Scope boundaries
- Performance requirements
- Security considerations

Present using AskUserQuestion (one question at a time, 2-4 options each).

**Wait for answers before Step 4.**

## Step 4: Design Architecture

Dispatch code-architect using Task tool:

```claude
Task tool (dev-workflow:code-architect):
  prompt: |
    Design architecture for [feature] using exploration context.

    Present 2 approaches:
    1. Minimal changes - smallest diff, maximum reuse
    2. Clean architecture - best maintainability

    For each: key files, components, trade-offs.
    Table comparison. Recommend one.

    Limit to 8 tool calls.
```

After return, use AskUserQuestion:

```claude
AskUserQuestion:
  header: "Approach"
  question: "Which approach?"
  multiSelect: false
  options:
    - label: "Minimal changes"
      description: "[Summary from architect - smallest diff, maximum reuse]"
    - label: "Clean architecture"
      description: "[Summary from architect - best maintainability]"
```

## Step 5: Write Plan

**Reference:** See `@${CLAUDE_PLUGIN_ROOT}/references/planning-philosophy.md` for task granularity and documentation requirements.

Save to: `docs/plans/YYYY-MM-DD-<feature-name>.md`

### Header (required)

```markdown
# [Feature Name] Implementation Plan

> **For Claude:** `/dev-workflow:execute-plan` for batch checkpoints, or `Skill("dev-workflow:subagent-driven-development")` for autonomous execution.
>
> **Methodology:** All tasks use `test-driven-development` skill (RED → GREEN → REFACTOR).

**Goal:** [One sentence]

**Architecture:** [2-3 sentences from Step 4]

**Tech Stack:** [Key technologies]

---
```

### Task Structure

Each task: one logical unit (10-30 minutes), TDD cycle included.

````markdown
### Task N: [Component Name]

**Files:**

- Create: `path/to/new.py`
- Modify: `path/to/existing.py:50-75`
- Test: `tests/path/to/test.py`

**Steps:**

1. Write failing test:
   ```python
   def test_behavior():
       result = function(input)
       assert result == expected
   ```
````

2. Run: `pytest tests/path/test.py::test_behavior -v`
   Expected: FAIL

3. Implement:

   ```python
   def function(input):
       return expected
   ```

4. Run: `pytest tests/path/test.py::test_behavior -v`
   Expected: PASS

5. Commit: `git add -A && git commit -m "feat: [description]"`

````

### Requirements

- Exact file paths (from exploration)
- Complete code (not "add validation")
- Exact commands with expected output
- TDD: test → fail → implement → pass → commit
- Each task references `test-driven-development` skill

Mark "Save Plan" `completed` in TodoWrite.

## Step 6: Execution Handoff

Use AskUserQuestion:

```claude
AskUserQuestion:
  header: "Execute"
  question: "Plan saved to [path]. How to proceed?"
  multiSelect: false
  options:
    - label: "Execute now"
      description: "Run /dev-workflow:execute-plan immediately"
    - label: "Later"
      description: "Save plan, execute manually when ready"
    - label: "Revise plan"
      description: "Provide feedback to adjust the plan"
```

### If "Execute now" selected:

Mark "Execution Handoff" `completed` in TodoWrite.

Invoke `/dev-workflow:execute-plan docs/plans/[filename].md`

### If "Later" selected:

Report:

```text
Plan saved to docs/plans/[filename].md

To execute later:
  /dev-workflow:execute-plan docs/plans/[filename].md
```

Mark "Execution Handoff" `completed` in TodoWrite.

### If "Revise plan" selected:

Respond with:

```text
What would you like me to change?
```

Wait for feedback. When provided:
1. Update plan file
2. Report changes briefly
3. Return to Step 6

## Verbosity Rules

**Interactive (Steps 1, 3, 4, 6):**

- AskUserQuestion for decisions
- Brief context before questions

**Silent (Steps 2, 5):**

- Tool calls only
- No narration during exploration or writing

**Progress:**

- Update TodoWrite after each step
- Brief status at step transitions

## Integration

| Component                                  | How write-plan uses it                              |
| ------------------------------------------ | --------------------------------------------------- |
| `dev-workflow:code-explorer`               | Step 2: Codebase survey                             |
| `dev-workflow:code-architect`              | Step 4: Architecture design                         |
| `dev-workflow:test-driven-development`     | Step 5: Task methodology (referenced in plan)       |
| `/dev-workflow:execute-plan`               | Step 6: Execution handoff                           |
| `/dev-workflow:brainstorm`                 | Upstream: Creates design docs this command consumes |
````
