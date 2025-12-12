# Skill Integration Reference

How skills work together in the development workflow.

## Concurrency Model

### Worktree Isolation

State files are worktree-scoped. Each worktree has its own `.claude/` directory.

```
main-repo/
├── .claude/
│   └── (no state files - main repo)
└── ...

../worktrees/feature-auth/
├── .claude/
│   └── dev-workflow-state.local.md  ← Session A state
└── ...

../worktrees/feature-api/
├── .claude/
│   └── dev-workflow-state.local.md  ← Session B state
└── ...
```

### State Files

| Workflow                    | State File                           | Scope    |
| --------------------------- | ------------------------------------ | -------- |
| /dev-workflow:execute-plan  | `.claude/dev-workflow-state.local.md` | Worktree |
| subagent-driven-development | `.claude/dev-workflow-state.local.md` | Worktree |

### Parallel Execution Rules

**Safe:** Multiple terminals in different worktrees
**Unsafe:** Multiple terminals in same worktree

Before parallel execution:

1. Load using-git-worktrees: `Skill("dev-workflow:using-git-worktrees")`
2. Create worktree for each parallel execution
3. Each session works in its own worktree

## Execution Workflows

### /dev-workflow:write-plan → subagent-driven-development

```
/dev-workflow:write-plan
    │
    ├─ Step 2: Task tool (dev-workflow:code-explorer)
    ├─ Step 4: Task tool (dev-workflow:code-architect)
    │           └─ Uses: pragmatic-architecture skill
    ├─ Step 5: Save plan
    │
    └─ Step 6: "Execute now" selected
           │
           ▼
    Skill("dev-workflow:subagent-driven-development")
           │
           ├─ Step 1: Initialize (state file, TodoWrite)
           ├─ Step 2: Analyze dependencies
           ├─ Step 3: Execute tasks (Task tool per task)
           ├─ Step 4: Final Code Review
           │     ├─ Task tool (dev-workflow:code-reviewer)
           │     │   └─ Uses: pragmatic-architecture skill
           │     └─ Skill("dev-workflow:receiving-code-review")
           └─ Step 5: Finish Branch
                 └─ Skill("dev-workflow:finishing-a-development-branch")
```

### /dev-workflow:write-plan → /dev-workflow:execute-plan

```
/dev-workflow:write-plan
    │
    └─ Step 6: "Batch execution" selected
           │
           ▼ (new session)
    /dev-workflow:execute-plan
           │
           ├─ Step 1: Initialize (state file, TodoWrite)
           ├─ Steps 2-5: Execute batches with checkpoints
           │     └─ AskUserQuestion between batches
           ├─ Step 6: Final Code Review
           │     ├─ Task tool (dev-workflow:code-reviewer)
           │     │   └─ Uses: pragmatic-architecture skill
           │     └─ Skill("dev-workflow:receiving-code-review")
           └─ Step 7: Complete
                 └─ Skill("dev-workflow:finishing-a-development-branch")
```

## Code Review Flow

```
requesting-code-review (WHEN to review)
        │
        ▼
Task tool (dev-workflow:code-reviewer) (DOES the review)
        │  └─ Checks: testing-anti-patterns + pragmatic-architecture
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
verification-before-completion (VERIFY each fix)
        │
        ▼
AskUserQuestion: "Proceed to finish?"
```

## Tool Usage Patterns

### Task tool for agents

```
Task tool (dev-workflow:code-reviewer):
  model: sonnet
  prompt: |
    [multi-line prompt]
```

### Skill tool for skills

```
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

```
USER REQUEST
    │
    ├── "Plan/design/brainstorm" ──────────► /dev-workflow:brainstorm command
    │                                              │
    │                                              ▼
    │                                        using-git-worktrees
    │
    ├── "Design/architect/structure" ──────► pragmatic-architecture
    │       │                                (via code-architect agent)
    │       └── Prevents over-engineering
    │
    ├── "Implement/add/write" ─────────────► TDD (always)
    │       │
    │       └── "Is this test good?" ──────► testing-anti-patterns
    │
    ├── "Bug/failing/not working" ─────────► systematic-debugging
    │       │
    │       ├── Deep call stack ───────────► root-cause-tracing
    │       ├── Flaky/intermittent ────────► condition-based-waiting
    │       │
    │       └── Root cause found ──────────► TDD (write failing test)
    │                                              │
    │                                              ▼
    │                                        defense-in-depth
    │
    ├── "Review my code" ──────────────────► requesting-code-review
    │       │                                     │
    │       │                                     ▼
    │       │                              code-reviewer agent
    │       │                              (uses pragmatic-architecture)
    │       │
    │       └── Feedback received ─────────► receiving-code-review
    │
    └── "Done/complete/fixed" ─────────────► verification-before-completion
```

## Skill Categories

### Workflow Skills (pipeline steps)

| Skill                              | When                  | What It Does              |
| ---------------------------------- | --------------------- | ------------------------- |
| /dev-workflow:brainstorm (command) | Planning phase        | Refine idea to design     |
| using-git-worktrees                | Before implementation | Create isolated workspace |
| finishing-a-development-branch     | After all tasks       | Clean merge to main       |

### Architecture Skills (design quality)

| Skill                  | When                      | What It Does                        |
| ---------------------- | ------------------------- | ----------------------------------- |
| pragmatic-architecture | Design/planning/review    | Prevents over-engineering           |
| defense-in-depth       | After bug fix             | Add validation at each layer        |

### Execution Skills (how to work)

| Skill                       | When                      | What It Does                        |
| --------------------------- | ------------------------- | ----------------------------------- |
| TDD                         | Any implementation        | Write test → Fail → Pass → Refactor |
| systematic-debugging        | Investigation             | Find root cause before fixing       |
| subagent-driven-development | Execute plan this session | Task tool per task, final review    |

### Quality Skills (ensure correctness)

| Skill                          | When                         | What It Does                       |
| ------------------------------ | ---------------------------- | ---------------------------------- |
| verification-before-completion | Any claim                    | Run command before claiming result |
| requesting-code-review         | Before merge / after feature | Dispatch code-reviewer agent       |
| receiving-code-review          | After code-reviewer returns  | Verify and implement feedback      |
| testing-anti-patterns          | Reviewing test code          | Identify test quality issues       |

## Completion Signals

Every workflow must end with explicit completion:

```
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
| Test was passing, now fails | systematic-debugging    | Investigate root cause |
| Writing new test            | TDD                     | Red-Green-Refactor     |
| Test sometimes passes/fails | condition-based-waiting | Fix flaky timing       |
| Is this test written well?  | testing-anti-patterns   | Evaluate quality       |

### TDD vs testing-anti-patterns

| Question                       | Skill                 |
| ------------------------------ | --------------------- |
| "How do I write this test?"    | TDD                   |
| "Is this test good?"           | testing-anti-patterns |
| "Write tests for this feature" | TDD                   |
| "Review these tests"           | testing-anti-patterns |

### verification-before-completion vs TDD

| Situation                   | Skill                          |
| --------------------------- | ------------------------------ |
| Writing new code with tests | TDD (includes verification)    |
| Claiming ANY result         | verification-before-completion |
| Running test once at end    | verification-before-completion |

verification-before-completion is a **principle** that applies everywhere.
TDD is a **methodology** for implementation.

### pragmatic-architecture vs defense-in-depth

| Situation                     | Skill                    |
| ----------------------------- | ------------------------ |
| Designing new feature         | pragmatic-architecture   |
| Reviewing proposed structure  | pragmatic-architecture   |
| After finding/fixing bug      | defense-in-depth         |
| Adding validation layers      | defense-in-depth         |

pragmatic-architecture is about **avoiding complexity**.
defense-in-depth is about **adding safety layers**.

## Skill Chains

### Feature Implementation (autonomous)

```
/dev-workflow:brainstorm (command)
    │
    ▼
using-git-worktrees
    │
    ▼
/dev-workflow:write-plan
    │   └─ code-architect uses pragmatic-architecture
    │
    ▼ (Step 6: "Execute now")
Skill("dev-workflow:subagent-driven-development")
    │
    ├─ TDD (each task via Task tool)
    │
    ├─ Task tool (dev-workflow:code-reviewer)
    │   ├─ Uses: testing-anti-patterns
    │   ├─ Uses: pragmatic-architecture
    │   └─ Skill("dev-workflow:receiving-code-review")
    │
    └─ Skill("dev-workflow:finishing-a-development-branch")
```

### Feature Implementation (checkpoints)

```
/dev-workflow:brainstorm (command)
    │
    ▼
using-git-worktrees
    │
    ▼
/dev-workflow:write-plan
    │   └─ code-architect uses pragmatic-architecture
    │
    ▼ (Step 6: "Batch execution")
/dev-workflow:execute-plan (new session)
    │
    ├─ TDD (each task)
    ├─ AskUserQuestion (each batch)
    │
    ├─ Task tool (dev-workflow:code-reviewer)
    │   ├─ Uses: testing-anti-patterns
    │   ├─ Uses: pragmatic-architecture
    │   └─ Skill("dev-workflow:receiving-code-review")
    │
    └─ Skill("dev-workflow:finishing-a-development-branch")
```

### Bug Fix

```
systematic-debugging
    │
    ├─ root-cause-tracing (if deep stack)
    ├─ condition-based-waiting (if flaky)
    │
    ▼
TDD (write failing test first)
    │
    ▼
defense-in-depth (add validation layers)
    │
    ▼
verification-before-completion
```
