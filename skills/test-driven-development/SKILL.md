---
name: test-driven-development
description: Use this skill when implementing any feature, bug fix, or plan task. Triggers on "write tests", "add a test", "do TDD", "test-driven", "implement with tests", "implement task", or when dispatched as a subagent for plan execution. Write test first, watch it fail, write minimal code to pass.
allowed-tools: Read, Edit, Bash
---

# Test-Driven Development (TDD)

Write the test first. Watch it fail. Write minimal code to pass.

**Core principle:** Without watching the test fail, there's no proof it tests the right thing.

## The Iron Law

```text
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Write code before the test? Delete it. Start over. No exceptions.

## Red-Green-Refactor Cycle

### RED - Write Failing Test

Write one minimal test showing what should happen.

```typescript
test("retries failed operations 3 times", async () => {
  let attempts = 0;
  const operation = () => {
    attempts++;
    if (attempts < 3) throw new Error("fail");
    return "success";
  };

  const result = await retryOperation(operation);

  expect(result).toBe("success");
  expect(attempts).toBe(3);
});
```

Requirements:
- One behavior per test
- Clear name describing behavior
- Real code (mocks only if unavoidable)

### Verify RED

**Mandatory. Never skip.**

```bash
npm test path/to/test.test.ts
```

Confirm:
- Test fails (not errors)
- Failure message is expected
- Fails because feature missing (not typos)

Test passes? Testing existing behavior. Fix test.

### GREEN - Minimal Code

Write simplest code to pass the test.

```typescript
async function retryOperation<T>(fn: () => Promise<T>): Promise<T> {
  for (let i = 0; i < 3; i++) {
    try {
      return await fn();
    } catch (e) {
      if (i === 2) throw e;
    }
  }
  throw new Error("unreachable");
}
```

Avoid adding features, refactoring, or "improving" beyond the test.

### Verify GREEN

**Mandatory.**

```bash
npm test path/to/test.test.ts
```

Confirm test passes, other tests still pass, output pristine.

### REFACTOR

After green only:
- Remove duplication
- Improve names
- Extract helpers

Keep tests green. Avoid adding behavior.

## Bug Fix Example

**Bug:** Empty email accepted

**RED:**
```typescript
test("rejects empty email", async () => {
  const result = await submitForm({ email: "" });
  expect(result.error).toBe("Email required");
});
```

**Verify RED:** `FAIL: expected 'Email required', got undefined`

**GREEN:**
```typescript
function submitForm(data: FormData) {
  if (!data.email?.trim()) {
    return { error: "Email required" };
  }
  // ...
}
```

**Verify GREEN:** `PASS`

## Verification Checklist

Before marking work complete:
- [ ] Every new function/method has a test
- [ ] Watched each test fail before implementing
- [ ] Each test failed for expected reason
- [ ] Wrote minimal code to pass each test
- [ ] All tests pass
- [ ] Output pristine (no errors, warnings)
- [ ] Tests use real code (mocks only if unavoidable)

Can't check all boxes? Start over with TDD.

## Red Flags - STOP and Start Over

- Code before test
- Test passes immediately
- Can't explain why test failed
- Rationalizing "just this once"
- "Keep as reference" or "adapt existing code"
- "Tests after achieve the same purpose"

**All of these mean: Delete code. Start over with TDD.**

## When Stuck

| Problem                | Solution                                |
| ---------------------- | --------------------------------------- |
| Don't know how to test | Write wished-for API first              |
| Test too complicated   | Design too complicated. Simplify.       |
| Must mock everything   | Code too coupled. Dependency injection. |
| Test setup huge        | Extract helpers or simplify design.     |

## Additional Resources

### Reference Files

- **`references/rationales.md`** - Why TDD order matters, common objections answered

### Related Skills

- **testing-anti-patterns** - Identifying problems in existing test code
- **systematic-debugging** - Bug found? Write failing test reproducing it
- **verification-before-completion** - Verify tests pass before claiming done