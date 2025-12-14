---
name: getting-started
description: This skill is loaded automatically at session start via SessionStart hook. Establishes protocols for finding and using skills, checking skills before tasks, brainstorming before coding, and creating TodoWrite for checklists.
allowed-tools: Read, Skill, TodoWrite
---

# Getting Started with Skills

## Skill Check Protocol

Before starting any task:

1. Scan available skills
2. Ask: "Does any skill match this task type?"
3. If yes: Load skill with Skill tool, announce it, follow it
4. Follow the skill exactly

Skills encode proven patterns that prevent common mistakes.

## When Skills Apply

Skills apply when the task involves:

- Testing (TDD, flaky tests, test quality)
- Debugging (bugs, failures, root cause)
- Planning (brainstorming, writing plans, executing plans)
- Code review (requesting, receiving)
- Git workflows (worktrees, branches, merging)
- Verification (completion claims, fix validation)

If a skill exists for the task type, use it.

## Shortcuts That Backfire

| Thought                            | Better Approach                                    |
| ---------------------------------- | -------------------------------------------------- |
| "This is just a simple question"   | Questions are tasks. Check for skills.             |
| "I can check git/files quickly"    | Skills tell HOW to check. Use them.                |
| "This doesn't need a formal skill" | If a skill exists, it exists for a reason.         |
| "I remember this skill"            | Skills evolve. Load the current version.           |
| "The skill is overkill"            | Skills exist because simple things become complex. |

## Skills with Checklists

If a skill contains a checklist, create TodoWrite items for each step.

Mental tracking of checklists leads to skipped steps. TodoWrite makes progress visible.

## Announcing Skill Usage

Before using a skill, announce it:

"I'm using [Skill Name] to [what you're doing]."

Examples:

- "I'm using the brainstorming skill to refine your idea into a design."
- "I'm using the dev-workflow:test-driven-development skill to implement this feature."

## Skill Types

**Rigid skills (follow exactly):** TDD, debugging, verification

- Adapting away the structure defeats the purpose.

**Flexible skills (adapt principles):** Architecture, brainstorming

- Core principles apply; specific steps adapt to context.

## Instructions vs. Workflows

User instructions describe WHAT to do, not HOW.

"Add X", "Fix Y" = the goal, not permission to skip brainstorming, TDD, or verification.

## Summary

1. Scan for relevant skills before starting any task
2. If skill exists: load it, announce it, follow it
3. Checklists require TodoWrite tracking
4. Rigid skills: follow exactly. Flexible skills: adapt principles.

## Reference

See `references/skill-integration.md` for decision tree and skill chains.

---

## Planning Methodology (EnterPlanMode)

When entering plan mode via `EnterPlanMode`, use this methodology:

### Phase 1: Explore

Use the native Explore agent with "very thorough" setting to survey the codebase:

- Similar features and existing patterns
- Integration points and boundaries
- Testing conventions and file locations
- Technology stack and frameworks

For complex features (touching 5+ files), dispatch code-architect agent:
```
Task(subagent_type: 'dev-workflow:code-architect',
     prompt: 'Design architecture for [feature]. Focus: minimal changes.')
```

### Phase 2: Design

Apply pragmatic-architecture principles:

| Principle | Rule |
|-----------|------|
| Rule of Three | Abstract only after 3+ occurrences |
| YAGNI | Design for today, not hypothetical futures |
| AHA | Prefer duplication over wrong abstraction |
| Colocation | Keep related code together, ≤3 files per feature |

### Phase 3: Write Plan

Each task MUST be self-contained with explicit TDD instructions (teammates may not have skill context):

````markdown
### Task N: [Component Name]

**Effort:** simple (3-10 tool calls) | standard (10-15) | complex (15-25)

**Files:**
- Create: `exact/path/to/new.py`
- Modify: `exact/path/to/existing.py:50-75`
- Test: `tests/exact/path/test.py`

**TDD Instructions (MANDATORY - follow exactly):**

1. **Write test FIRST** - Before ANY implementation:
   ```python
   def test_behavior():
       # Arrange
       input_data = {...}
       # Act
       result = function(input_data)
       # Assert
       assert result == expected
   ```

2. **Run test, verify FAILURE:**
   ```bash
   pytest tests/path -v
   ```
   Expected: FAIL (proves test catches missing behavior)

3. **Implement MINIMAL code** - Only enough to pass the test, nothing extra

4. **Run test, verify PASS:**
   ```bash
   pytest tests/path -v
   ```
   Expected: PASS (all tests green)

5. **Commit with conventional format:**
   ```bash
   git add -A && git commit -m "feat(scope): description"
   ```

**Why TDD order matters:** Writing tests after implementation doesn't prove the test catches bugs - it only proves the test matches what was written.
````

### Task Requirements

- Exact file paths (from exploration)
- Complete code snippets (not "add validation")
- Test commands with expected output
- TDD cycle: test → fail → implement → pass → commit

### Parallel Groups

Tasks with NO file overlap execute in parallel (3-5 per group):

| Task Group | Tasks | Rationale |
|------------|-------|-----------|
| Group 1 | 1, 2, 3 | Independent modules, no file overlap |
| Group 2 | 4, 5 | Both touch shared types, must be serial |
| Group 3 | 6, 7, 8 | Independent tests, no file overlap |

### Final Task

Always include "Code Review" as the final task.

### Swarm Execution

Use `ExitPlanMode(launchSwarm: true, teammateCount: N)` to spawn parallel teammates.

**Calculate teammateCount:**
| Independent Groups | teammateCount |
|--------------------|---------------|
| 1-2 groups | 2 |
| 3-4 groups | 3-4 |
| 5+ groups | 5 (max) |

**Execution behavior:**
- Each teammate executes one task following embedded TDD instructions
- Each task = one commit
- Teammates work in parallel where tasks have no file overlap
- Tasks in same group with file overlap run sequentially

### Post-Swarm Actions

After swarm completes, the main session must:

1. **Code Review** - Dispatch code-reviewer agent:
   ```claude
   Task:
     subagent_type: dev-workflow:code-reviewer
     description: "Review all changes"
     prompt: "Review changes from plan execution. git diff main..HEAD"
   ```

2. **Process Feedback** - Use `Skill("dev-workflow:receiving-code-review")`

3. **Finish Branch** - Use `Skill("dev-workflow:finishing-a-development-branch")`

These steps are MANDATORY after swarm execution.
