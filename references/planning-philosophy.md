# Planning Philosophy

<!--
PURPOSE: Core philosophy for write-plan command and subagent execution.
LOADED BY: commands/write-plan.md, skills/subagent-driven-development
-->

## The Golden Rule

**Write plans assuming the executor has zero context and questionable taste.**

They are skilled developers who know almost nothing about:

- This codebase's conventions
- The problem domain
- Good test design

They will take shortcuts if the plan allows it.

## What to Document

Every task must include:

- Exact file paths (not "update the config")
- Complete code snippets (not "add validation")
- Test commands to run
- Expected output
- Commit message

## Task Granularity

Each task = one TDD cycle (10-30 minutes):

1. Write failing test
2. Run to verify failure
3. Implement minimal code
4. Run to verify pass
5. Commit

## Quick Reference

| Good                            | Bad              |
| ------------------------------- | ---------------- |
| `src/auth/login.ts:42`          | "the auth file"  |
| `expect(result).toBe(42)`       | "add assertions" |
| `npm test -- --grep "login"`    | "run the tests"  |
| "Returns 401 for invalid token" | "should fail"    |
