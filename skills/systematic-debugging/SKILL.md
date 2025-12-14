---
name: systematic-debugging
description: This skill should be used when the user reports a "bug", "not working", "fix this", "debug", "test failing", or when investigating unexpected behavior. Four-phase framework ensuring root cause understanding before attempting solutions.
allowed-tools: Read, Bash, Grep, Skill
---

# Systematic Debugging

Random fixes waste time and create new bugs.

**Core principle:** ALWAYS find root cause before attempting fixes.

## The Iron Law

```text
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

Without completing Phase 1, fixes cannot be proposed.

## The Four Phases

### Phase 1: Root Cause Investigation

**BEFORE attempting ANY fix:**

1. **Read error messages carefully** - They often contain the solution
2. **Reproduce consistently** - If not reproducible, gather more data
3. **Check recent changes** - Git diff, new dependencies, config changes
4. **Trace data flow** - Where does bad value originate?

For deep call stack errors, use **root-cause-tracing** skill.

For multi-component systems, add diagnostic instrumentation at each boundary before proposing fixes.

### Phase 2: Pattern Analysis

1. **Find working examples** - Similar working code in same codebase
2. **Compare against references** - Read reference implementation completely
3. **Identify differences** - List every difference, however small
4. **Understand dependencies** - What settings, config, environment?

### Phase 3: Hypothesis and Testing

1. **Form single hypothesis** - "I think X is the root cause because Y"
2. **Test minimally** - Smallest possible change, one variable at a time
3. **Verify before continuing** - Didn't work? Form NEW hypothesis

### Phase 4: Implementation

1. **Create failing test case** - Use **dev-workflow:test-driven-development** skill
2. **Implement single fix** - ONE change, no bundled improvements
3. **Verify fix** - Test passes, no regressions
4. **If 3+ fixes failed** - Question architecture, not symptoms

## Red Flags - STOP

When catching these thoughts:

- "Quick fix for now, investigate later"
- "Just try changing X and see"
- "It's probably X, let me fix that"
- "I don't fully understand but this might work"
- Proposing solutions before tracing data flow

**All mean: STOP. Return to Phase 1.**

## Quick Reference

| Phase             | Key Activities                 | Success Criteria            |
| ----------------- | ------------------------------ | --------------------------- |
| 1. Root Cause     | Read errors, reproduce, trace  | Understand WHAT and WHY     |
| 2. Pattern        | Find working examples, compare | Identify differences        |
| 3. Hypothesis     | Form theory, test minimally    | Confirmed or new hypothesis |
| 4. Implementation | Create test, fix, verify       | Bug resolved, tests pass    |

## When 3+ Fixes Failed

Pattern indicating architectural problem:

- Each fix reveals new problem in different place
- Fixes require "massive refactoring"
- Each fix creates new symptoms elsewhere

**STOP and question fundamentals.** Discuss before attempting more fixes.

## Additional Resources

### Reference Files

For detailed guidance:

- **`references/phase-details.md`** - Expanded phase procedures
- **`references/rationalizations.md`** - Common excuses and rebuttals

## Integration

- **dev-workflow:root-cause-tracing** - REQUIRED for deep call stack errors (Phase 1)
- **dev-workflow:test-driven-development** - REQUIRED for failing test case (Phase 4)
- **dev-workflow:defense-in-depth** - Add validation layers after fix
- **dev-workflow:verification-before-completion** - Verify fix before claiming success
