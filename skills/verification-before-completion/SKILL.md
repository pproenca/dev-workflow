---
name: verification-before-completion
description: This skill should be used when claiming a task is "done", "complete", "finished", "fixed", "passing", or before committing. Requires running verification commands before making success claims.
allowed-tools: Read, Bash, Grep, Glob
---

# Verification Before Completion

**Core principle:** Run the command. Read the output. THEN claim the result.

## The Rule

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

## Before Any Claim

1. **Identify** - What command proves this claim?
2. **Run** - Execute the full command
3. **Read** - Check output, exit code, failure count
4. **Claim** - State result WITH evidence

## What Requires Verification

| Claim          | Run This                     |
| -------------- | ---------------------------- |
| Tests pass     | Test command, see 0 failures |
| Build succeeds | Build command, see exit 0    |
| Bug fixed      | Test original symptom        |
| Linter clean   | Linter command, see 0 errors |

## Red Flags

Stop when catching these thoughts:

- "Should work now"
- "I'm confident"
- "Linter passed" (linter ≠ tests)
- Using "probably", "seems to"

**All mean: RUN the verification first.**

## Examples

```
✅ [Run npm test] [See: 34/34 pass] "All tests pass"
❌ "Should pass now"

✅ [Run build] [See: exit 0] "Build succeeds"
❌ "Linter passed" (linter doesn't verify build)
```

## The Bottom Line

No shortcuts. Run the command. Read the output. Then claim.

## Integration

This principle applies at every claim point:

- **TDD** - Verify RED, verify GREEN
- **execute-plan** - Verify before checkpoint
- **subagent-driven-development** - Verify subagent reports independently
- **finishing-a-development-branch** - Verify tests before merge options

Triggers independently when making claims outside formal workflows.
