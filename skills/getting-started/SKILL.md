---
name: getting-started
description: This skill is loaded automatically at session start via SessionStart hook. Establishes protocols for finding and using skills, checking skills before tasks, brainstorming before coding, and creating TodoWrite for checklists.
allowed-tools: Read, Grep, Glob, Skill, TodoWrite
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
- "I'm using the test-driven-development skill to implement this feature."

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
