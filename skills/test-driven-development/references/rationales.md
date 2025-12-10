# TDD Rationales

Why the order matters and responses to common objections.

## Why Test-First Order Matters

### "I'll write tests after to verify it works"

Tests written after code pass immediately. Passing immediately proves nothing:

- Might test wrong thing
- Might test implementation, not behavior
- Might miss forgotten edge cases
- Never saw it catch the bug

Test-first forces seeing the test fail, proving it actually tests something.

### "I already manually tested all the edge cases"

Manual testing is ad-hoc:

- No record of what was tested
- Can't re-run when code changes
- Easy to forget cases under pressure
- "It worked when I tried it" ≠ comprehensive

Automated tests are systematic. They run the same way every time.

### "Deleting X hours of work is wasteful"

Sunk cost fallacy. The time is already gone. The choice now:

- Delete and rewrite with TDD (X more hours, high confidence)
- Keep it and add tests after (30 min, low confidence, likely bugs)

The "waste" is keeping code that can't be trusted.

### "TDD is dogmatic, being pragmatic means adapting"

TDD IS pragmatic:

- Finds bugs before commit (faster than debugging after)
- Prevents regressions (tests catch breaks immediately)
- Documents behavior (tests show how to use code)
- Enables refactoring (change freely, tests catch breaks)

"Pragmatic" shortcuts = debugging in production = slower.

### "Tests after achieve the same goals - it's spirit not ritual"

No. Tests-after answer "What does this do?" Tests-first answer "What should this do?"

Tests-after are biased by the implementation:

- Testing what was built, not what's required
- Verifying remembered edge cases, not discovered ones

Tests-first force edge case discovery before implementing.

30 minutes of tests after ≠ TDD. Getting coverage, losing proof tests work.

## Good vs Bad Tests

| Quality          | Good                        | Bad                                                 |
| ---------------- | --------------------------- | --------------------------------------------------- |
| **Minimal**      | One thing per test          | `test('validates email and domain and whitespace')` |
| **Clear**        | Name describes behavior     | `test('test1')`                                     |
| **Shows intent** | Demonstrates desired API    | Obscures what code should do                        |
| **Real code**    | Tests actual implementation | Tests mock behavior                                 |

## Final Rule

```
Production code → test exists and failed first
Otherwise → not TDD
```

No exceptions without explicit permission.
