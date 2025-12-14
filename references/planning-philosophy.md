# Planning Philosophy

## The Golden Rule

**Write plans assuming the executor has zero context and questionable taste.**

They are skilled developers who know almost nothing about:

- This codebase's conventions
- The problem domain
- Good test design
- When to abstract vs duplicate

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

## File Organization Rules

**Apply dev-workflow:pragmatic-architecture principles:**

| Rule | Guidance |
|------|----------|
| Rule of Three | Don't create shared utilities until 3rd use |
| Colocation | Keep related code in same file/folder |
| YAGNI | No "for future use" abstractions |
| File Count | ≤3 new files per feature |

**Plan should specify:**
- Why each new file exists (can't be merged elsewhere)
- Where types/utils live (inline preferred over separate files)
- Expected file sizes (flag if <50 lines)

## Quick Reference

| Good                            | Bad              |
| ------------------------------- | ---------------- |
| `src/auth/login.ts:42`          | "the auth file"  |
| `expect(result).toBe(42)`       | "add assertions" |
| `npm test -- --grep "login"`    | "run the tests"  |
| "Returns 401 for invalid token" | "should fail"    |
| Types inline in component       | Separate `types.ts` for 3 types |
| 2 files for feature             | 8 files for feature |

## Anti-Patterns in Plans

Plans should NOT include:

- Abstract base classes without 2+ concrete implementations
- Utility files for single-use functions
- Type-only files (inline types where used)
- "Extensibility" or "plugin" patterns without concrete extensions
- Folders like `types/`, `utils/`, `constants/` that scatter related code
