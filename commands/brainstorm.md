---
description: Interactive design refinement using Socratic method
argument-hint: [topic or @design-doc.md]
allowed-tools: Read, Write, Bash, Grep, Glob, AskUserQuestion
---

# Brainstorm Session

Refine this idea into a design through collaborative dialogue.

## Input

$ARGUMENTS

**If empty or no arguments:** Use AskUserQuestion to ask what the user wants to brainstorm.

## Process

### 1. Understand Context

Check project state first:

```bash
ls -la
git log --oneline -5 2>/dev/null || true
```

If `$ARGUMENTS` references a file (`@...`), read it.

### 2. Clarify the Idea

Ask questions **one at a time** using AskUserQuestion:

- Purpose and goals
- Constraints and requirements
- Success criteria

Use structured options (2-4 per question):

```
AskUserQuestion:
  header: "Scope"
  question: "What is the primary goal?"
  multiSelect: false
  options:
    - label: "Option A"
      description: "Trade-off explanation"
    - label: "Option B"
      description: "Trade-off explanation"
```

Reserve open-ended questions for truly exploratory topics.

### 3. Explore Approaches

Propose 2-3 approaches with trade-offs.

Use AskUserQuestion to present options:

```
AskUserQuestion:
  header: "Approach"
  question: "Which direction?"
  multiSelect: false
  options:
    - label: "[Recommended approach]"
      description: "Key benefit and trade-off"
    - label: "[Alternative approach]"
      description: "Key benefit and trade-off"
```

Lead with recommended option.

### 4. Present Design

Once requirements are clear:

- Present in sections of 200-300 words
- Ask after each section if it looks right
- Cover: architecture, components, data flow, error handling
- Go back and clarify if needed

### 5. Save Design

Write to `docs/plans/YYYY-MM-DD-<topic>-design.md`

Commit: `git add -A && git commit -m "docs: <topic> design"`

### 6. Handoff

Use AskUserQuestion:

```
AskUserQuestion:
  header: "Next"
  question: "Design saved. What next?"
  multiSelect: false
  options:
    - label: "Create plan"
      description: "Run /dev-workflow:write-plan @docs/plans/<file>.md"
    - label: "Keep exploring"
      description: "Continue refining the design"
    - label: "Done"
      description: "End session, design is complete"
```

## Principles

- **One question at a time** - Don't overwhelm
- **YAGNI** - Remove unnecessary features from designs
- **Incremental validation** - Check each section before continuing
- **Simplest solution first** - Prefer boring over clever

## Design Quality Gates

Before saving, verify the design does NOT include:

| Red Flag | Action |
|----------|--------|
| "For future extensibility" | Remove - solve today's problem |
| Abstract classes with 1 implementation | Simplify to concrete |
| Plugin/hook systems without plugins | Remove until needed |
| More than 3 new files per feature | Consolidate |

These will be enforced by code-architect during planning, but catching early saves iteration.
