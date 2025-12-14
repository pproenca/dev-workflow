# Skill Integration Reference

How skills work together in the development workflow.

## Native Planning Flow

```text
/dev-workflow:brainstorm (optional)
    │
    ▼
EnterPlanMode
    │
    ├── Explore codebase (native Explore agent)
    ├── Design with dev-workflow:pragmatic-architecture principles
    ├── Write plan with TDD tasks
    │
    ▼
ExitPlanMode(launchSwarm: true, teammateCount: 3-5)
    │
    ├── Teammates execute tasks in parallel
    │   └── Each task: TDD cycle → commit
    │
    ▼
Post-swarm actions (main session):
    ├── Task(dev-workflow:code-reviewer)
    ├── Skill("dev-workflow:receiving-code-review")
    └── Skill("dev-workflow:finishing-a-development-branch")
```

## Code Review Flow

```text
requesting-code-review (WHEN to review)
        │
        ▼
Task tool (dev-workflow:code-reviewer) (DOES the review)
        │  └─ Checks: dev-workflow:testing-anti-patterns + dev-workflow:pragmatic-architecture
        │
        ▼
Skill("dev-workflow:receiving-code-review") (PROCESS feedback)
        │
        ├── Critical → fix immediately, test, commit
        ├── Important → fix before proceeding, test, commit
        ├── Architecture → simplify over-engineered code
        ├── Unclear → ask clarification FIRST
        └── Wrong → push back with reasoning
        │
        ▼
dev-workflow:verification-before-completion (VERIFY each fix)
        │
        ▼
AskUserQuestion: "Proceed to finish?"
```

## Tool Usage Patterns

### Task tool for agents

```claude
Task tool (dev-workflow:code-reviewer):
  model: opus
  prompt: |
    [multi-line prompt]
```

### Skill tool for skills

```claude
Skill("dev-workflow:receiving-code-review")
```

### AskUserQuestion for decisions

- header: "[max 12 chars]"
- question: "[full question]"
- options:
  - [Label] ([Description])
  - [Label] ([Description])

### TodoWrite for progress

- Create items at workflow start
- Mark `in_progress` when starting
- Mark `completed` when done

## Trigger Decision Tree

```text
USER REQUEST
    │
    ├── "Plan/design/brainstorm" ──────────► /dev-workflow:brainstorm command
    │                                              │
    │                                              ▼
    │                                        EnterPlanMode
    │
    ├── "Design/architect/structure" ──────► dev-workflow:pragmatic-architecture
    │       │                                (via code-architect agent)
    │       └── Prevents over-engineering
    │
    ├── "Implement/add/write" ─────────────► TDD (always)
    │       │
    │       └── "Is this test good?" ──────► dev-workflow:testing-anti-patterns
    │
    ├── "Bug/failing/not working" ─────────► dev-workflow:systematic-debugging
    │       │
    │       ├── Deep call stack ───────────► dev-workflow:root-cause-tracing
    │       ├── Flaky/intermittent ────────► dev-workflow:condition-based-waiting
    │       │
    │       └── Root cause found ──────────► TDD (write failing test)
    │                                              │
    │                                              ▼
    │                                        dev-workflow:defense-in-depth
    │
    ├── "Review my code" ──────────────────► requesting-code-review
    │       │                                     │
    │       │                                     ▼
    │       │                              code-reviewer agent
    │       │                              (uses dev-workflow:pragmatic-architecture)
    │       │
    │       └── Feedback received ─────────► dev-workflow:receiving-code-review
    │
    └── "Done/complete/fixed" ─────────────► dev-workflow:verification-before-completion
```

## Skill Categories

### Architecture Skills (design quality)

| Skill                  | When                      | What It Does                        |
| ---------------------- | ------------------------- | ----------------------------------- |
| dev-workflow:pragmatic-architecture | Design/planning/review    | Prevents over-engineering           |
| dev-workflow:defense-in-depth       | After bug fix             | Add validation at each layer        |

### Execution Skills (how to work)

| Skill                       | When                      | What It Does                        |
| --------------------------- | ------------------------- | ----------------------------------- |
| TDD                         | Any implementation        | Write test → Fail → Pass → Refactor |
| dev-workflow:systematic-debugging        | Investigation             | Find root cause before fixing       |

### Quality Skills (ensure correctness)

| Skill                          | When                         | What It Does                       |
| ------------------------------ | ---------------------------- | ---------------------------------- |
| dev-workflow:verification-before-completion | Any claim                    | Run command before claiming result |
| requesting-code-review         | Before merge / after feature | Dispatch code-reviewer agent       |
| dev-workflow:receiving-code-review          | After code-reviewer returns  | Verify and implement feedback      |
| dev-workflow:testing-anti-patterns          | Reviewing test code          | Identify test quality issues       |

## Completion Signals

Every workflow must end with explicit completion:

```text
✓ [What was done]
✓ [Test results]
✓ [Final state]

Workflow complete.
```

This signals to both user and model that the workflow is finished.

## Common Confusions

### "Test failing" - Which skill?

| Situation                   | Skill                   | Why                    |
| --------------------------- | ----------------------- | ---------------------- |
| Test was passing, now fails | dev-workflow:systematic-debugging    | Investigate root cause |
| Writing new test            | TDD                     | Red-Green-Refactor     |
| Test sometimes passes/fails | dev-workflow:condition-based-waiting | Fix flaky timing       |
| Is this test written well?  | dev-workflow:testing-anti-patterns   | Evaluate quality       |

### TDD vs dev-workflow:testing-anti-patterns

| Question                       | Skill                 |
| ------------------------------ | --------------------- |
| "How do I write this test?"    | TDD                   |
| "Is this test good?"           | dev-workflow:testing-anti-patterns |
| "Write tests for this feature" | TDD                   |
| "Review these tests"           | dev-workflow:testing-anti-patterns |

### dev-workflow:verification-before-completion vs TDD

| Situation                   | Skill                          |
| --------------------------- | ------------------------------ |
| Writing new code with tests | TDD (includes verification)    |
| Claiming ANY result         | dev-workflow:verification-before-completion |
| Running test once at end    | dev-workflow:verification-before-completion |

dev-workflow:verification-before-completion is a **principle** that applies everywhere.
TDD is a **methodology** for implementation.

### dev-workflow:pragmatic-architecture vs dev-workflow:defense-in-depth

| Situation                     | Skill                    |
| ----------------------------- | ------------------------ |
| Designing new feature         | dev-workflow:pragmatic-architecture   |
| Reviewing proposed structure  | dev-workflow:pragmatic-architecture   |
| After finding/fixing bug      | dev-workflow:defense-in-depth         |
| Adding validation layers      | dev-workflow:defense-in-depth         |

dev-workflow:pragmatic-architecture is about **avoiding complexity**.
dev-workflow:defense-in-depth is about **adding safety layers**.

## Skill Chains

### Feature Implementation

```text
/dev-workflow:brainstorm (optional)
    │
    ▼
EnterPlanMode
    │   └─ code-architect uses dev-workflow:pragmatic-architecture
    │
    ▼
ExitPlanMode(launchSwarm: true)
    │
    ├─ TDD (each task via swarm teammates)
    │
    ├─ Task tool (dev-workflow:code-reviewer)
    │   ├─ Uses: dev-workflow:testing-anti-patterns
    │   ├─ Uses: dev-workflow:pragmatic-architecture
    │   └─ Skill("dev-workflow:receiving-code-review")
    │
    └─ Skill("dev-workflow:finishing-a-development-branch")
```

### Bug Fix

```text
dev-workflow:systematic-debugging
    │
    ├─ dev-workflow:root-cause-tracing (if deep stack)
    ├─ dev-workflow:condition-based-waiting (if flaky)
    │
    ▼
TDD (write failing test first)
    │
    ▼
dev-workflow:defense-in-depth (add validation layers)
    │
    ▼
dev-workflow:verification-before-completion
```
