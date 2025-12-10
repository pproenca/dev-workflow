---
name: testing-anti-patterns
description: This skill should be used when reviewing test code, the user asks "is this test good", "test quality", "mock properly", or when tests behave unexpectedly. Identifies common testing mistakes.
allowed-tools: Read, Grep, Glob
---

# Testing Anti-Patterns

Tests must verify real behavior, not mock behavior.

**Core principle:** Test what the code does, not what the mocks do.

## Anti-Pattern 1: Testing Mock Behavior

```typescript
// ❌ BAD: Testing that mock exists
test("renders sidebar", () => {
  render(<Page />);
  expect(screen.getByTestId("sidebar-mock")).toBeInTheDocument();
});

// ✅ GOOD: Test real component
test("renders sidebar", () => {
  render(<Page />);
  expect(screen.getByRole("navigation")).toBeInTheDocument();
});
```

**Gate:** Before asserting on mock elements, ask: "Am I testing real behavior or mock existence?"

## Anti-Pattern 2: Test-Only Methods in Production

```typescript
// ❌ BAD: destroy() only used in tests
class Session {
  async destroy() {
    /* cleanup */
  }
}

// ✅ GOOD: Test utilities handle cleanup
// In test-utils/
export async function cleanupSession(session: Session) {
  /* cleanup */
}
```

**Gate:** Before adding method to production class, ask: "Is this only used by tests?"

## Anti-Pattern 3: Mocking Without Understanding

```typescript
// ❌ BAD: Mock breaks test logic
vi.mock("ToolCatalog", () => ({
  discoverAndCacheTools: vi.fn(), // Removes side effect test needs!
}));

// ✅ GOOD: Mock at correct level
vi.mock("MCPServerManager"); // Mock the slow part, preserve needed behavior
```

**Gate:** Before mocking, ask: "What side effects does this have? Does my test depend on them?"

## Anti-Pattern 4: Incomplete Mocks

```typescript
// ❌ BAD: Partial mock
const mockResponse = {
  status: "success",
  data: { userId: "123" },
  // Missing: metadata that downstream code uses
};

// ✅ GOOD: Complete mock
const mockResponse = {
  status: "success",
  data: { userId: "123" },
  metadata: { requestId: "req-789", timestamp: 1234567890 },
};
```

**Gate:** Before creating mock, ask: "What fields does the real response contain?"

## Red Flags

- Assertions on `*-mock` test IDs
- Methods only called in test files
- Mock setup is >50% of test
- Test fails when mock is removed
- Can't explain why mock is needed

## Quick Reference

| Anti-Pattern                 | Fix                           |
| ---------------------------- | ----------------------------- |
| Assert on mock elements      | Test real component           |
| Test-only production methods | Move to test utilities        |
| Mock without understanding   | Understand dependencies first |
| Incomplete mocks             | Mirror real API completely    |

## Integration

**Use this skill for:** Reviewing existing test code quality

**Use TDD skill for:** Writing new tests correctly

The distinction: TDD is HOW to write tests. This skill is IS THIS TEST GOOD.
