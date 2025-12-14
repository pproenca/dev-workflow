# User Story Map: dev-workflow Plugin

**Date:** 2025-12-14
**Context:** Breaking change analysis for `641f3d3` (replace custom orchestration with native swarm support)
**Methodology:** Jeff Patton's User Story Mapping

---

## Story Map Overview

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                              BACKBONE (Activities)                                               │
├──────────────────┬──────────────────┬──────────────────┬──────────────────┬──────────────────┬──────────────────┤
│    IDEATION      │    PLANNING      │    EXECUTION     │  QUALITY ASSUR.  │ SESSION MGMT     │   INTEGRATION    │
│                  │                  │                  │                  │                  │                  │
│  Refine ideas    │  Create impl     │  Run plans       │  Ensure code     │  Persist state   │  Merge/PR        │
│  into designs    │  plans           │  (tasks)         │  quality         │  across sessions │  work            │
└──────────────────┴──────────────────┴──────────────────┴──────────────────┴──────────────────┴──────────────────┘
```

---

## 1. IDEATION Activity

### User Tasks

| Task | Description |
|------|-------------|
| **T1.1** Brainstorm feature | Interactive design refinement using Socratic method |
| **T1.2** Explore codebase | Understand existing patterns before designing |
| **T1.3** Save design | Persist design document for later reference |

### User Stories

#### T1.1 Brainstorm feature

| ID | Story | Priority | Status |
|----|-------|----------|--------|
| **US-1.1.1** | As a developer, I want to brainstorm a feature idea interactively so that I can refine requirements before implementation | MVP | **WORKING** |
| **US-1.1.2** | As a developer, I want to receive structured questions (2-4 options) so that I can make decisions efficiently | MVP | **WORKING** |
| **US-1.1.3** | As a developer, I want design quality gates (YAGNI, Rule of Three) enforced so that I don't over-engineer | MVP | **WORKING** |

#### T1.2 Explore codebase

| ID | Story | Priority | Status |
|----|-------|----------|--------|
| **US-1.2.1** | As a developer, I want the assistant to survey similar features before designing so that we follow existing patterns | MVP | **WORKING** |
| **US-1.2.2** | As a developer, I want the code-architect agent dispatched for complex features so that I get expert design input | MVP | **WORKING** |

#### T1.3 Save design

| ID | Story | Priority | Status |
|----|-------|----------|--------|
| **US-1.3.1** | As a developer, I want designs saved to `docs/plans/` with date prefix so that I can find them later | MVP | **WORKING** |
| **US-1.3.2** | As a developer, I want a handoff prompt after saving so that I can choose next steps | MVP | **WORKING** |

---

## 2. PLANNING Activity

### User Tasks

| Task | Description |
|------|-------------|
| **T2.1** Create plan | Generate detailed implementation plan with TDD tasks |
| **T2.2** Review plan | Validate plan before execution |
| **T2.3** Adapt plan | Modify existing plan for different context |

### User Stories

#### T2.1 Create plan

| ID | Story | Priority | Status |
|----|-------|----------|--------|
| **US-2.1.1** | As a developer, I want to enter plan mode to design implementation so that I can get user approval before coding | MVP | **WORKING** (was `/dev-workflow:write-plan`, now `EnterPlanMode`) |
| **US-2.1.2** | As a developer, I want tasks to have exact file paths, code snippets, and test commands so that execution is unambiguous | MVP | **WORKING** |
| **US-2.1.3** | As a developer, I want tasks grouped by file dependencies so that parallel execution is safe | MVP | **WORKING** |
| **US-2.1.4** | As a developer, I want effort estimates (simple/standard/complex) on tasks so that I can estimate total work | Nice | **WORKING** |
| **US-2.1.5** | As a developer, I want ambiguities clarified via AskUserQuestion BEFORE writing the plan so that execution doesn't block on decisions | MVP | **WORKING** |

#### T2.2 Review plan

| ID | Story | Priority | Status |
|----|-------|----------|--------|
| **US-2.2.1** | As a developer, I want to review the plan file before approving execution so that I can catch issues early | MVP | **WORKING** |
| **US-2.2.2** | As a developer, I want "Code Review" as the final task in every plan so that quality is ensured | MVP | **WORKING** |

#### T2.3 Adapt plan

| ID | Story | Priority | Status |
|----|-------|----------|--------|
| **US-2.3.1** | As a developer, I want to use an existing plan file from a previous session so that I don't have to re-plan | Nice | **DEGRADED** - see analysis below |
| **US-2.3.2** | As a developer, I want to modify a plan before execution so that I can adjust scope | Nice | **WORKING** |

---

## 3. EXECUTION Activity

### User Tasks

| Task | Description |
|------|-------------|
| **T3.1** Execute sequentially | Run tasks one by one in current session |
| **T3.2** Execute in parallel (swarm) | Run independent tasks concurrently via subagents |
| **T3.3** Execute with checkpoints | Batch execution with human review between batches |
| **T3.4** Resume execution | Continue from where we left off after interruption |

### User Stories

#### T3.1 Execute sequentially

| ID | Story | Priority | Status |
|----|-------|----------|--------|
| **US-3.1.1** | As a developer, I want to execute tasks sequentially in the current session so that I have full control | MVP | **WORKING** (described in getting-started skill) |
| **US-3.1.2** | As a developer, I want each task to follow TDD (test first, fail, implement, pass) so that quality is built-in | MVP | **WORKING** |
| **US-3.1.3** | As a developer, I want each task to commit after completion so that progress is atomic | MVP | **WORKING** |

#### T3.2 Execute in parallel (swarm)

| ID | Story | Priority | Status |
|----|-------|----------|--------|
| **US-3.2.1** | As a developer, I want to launch a swarm to execute independent tasks in parallel so that implementation is faster | MVP | **WORKING** (`ExitPlanMode(launchSwarm: true)`) |
| **US-3.2.2** | As a developer, I want teammates to work in parallel where tasks have no file overlap so that there are no git conflicts | MVP | **WORKING** (native swarm behavior) |
| **US-3.2.3** | As a developer, I want to specify the number of teammates so that I can control resource usage | MVP | **WORKING** (`teammateCount` parameter) |

##### REMOVED Stories (previously supported)

| ID | Story | Previous Support | Status |
|----|-------|------------------|--------|
| **US-3.2.4** | As a developer, I want subagents to work in ephemeral worktrees so that git operations are isolated and safe | Was supported via `create_ephemeral_worktree()` | **BROKEN** - Native swarm doesn't use worktrees |
| **US-3.2.5** | As a developer, I want subagent outputs written to `.claude/task-outputs/` so that I can inspect results | Was supported via lightweight reference pattern | **BROKEN** - No filesystem output from swarm |
| **US-3.2.6** | As a developer, I want ephemeral branches merged back in task order so that commit history is clean | Was supported via `merge_ephemeral_group()` | **BROKEN** - No branch merging |

#### T3.3 Execute with checkpoints

| ID | Story | Priority | Status |
|----|-------|----------|--------|
| **US-3.3.1** | As a developer, I want batch checkpoints every N tasks so that I can review progress and decide to continue | Nice | **BROKEN** - `/dev-workflow:execute-plan` removed |
| **US-3.3.2** | As a developer, I want to pause execution at checkpoints and resume later so that I can take breaks | Nice | **BROKEN** - No state persistence |
| **US-3.3.3** | As a developer, I want a "Review" option at checkpoints showing git log/diff so that I can inspect changes | Nice | **BROKEN** - No checkpoint system |

#### T3.4 Resume execution

| ID | Story | Priority | Status |
|----|-------|----------|--------|
| **US-3.4.1** | As a developer, I want to resume plan execution in a new session so that I can continue after closing my terminal | Critical | **BROKEN** - No state file |
| **US-3.4.2** | As a developer, I want the state file to track `current_task`, `total_tasks`, `last_commit` so that resume knows where to continue | Critical | **BROKEN** - No state file |
| **US-3.4.3** | As a developer, I want `/dev-workflow:workflow-status` to show active workflow and offer Continue/Reset so that I can manage workflows | Nice | **BROKEN** - Command removed |
| **US-3.4.4** | As a developer, I want progress logged to `.claude/dev-workflow-progress.log` so that context can be restored on resume | Nice | **BROKEN** - No progress log |

---

## 4. QUALITY ASSURANCE Activity

### User Tasks

| Task | Description |
|------|-------------|
| **T4.1** Enforce TDD | Ensure tests are written before implementation |
| **T4.2** Code review | Review all changes before completion |
| **T4.3** Enforce commits | Ensure subagents commit their work |

### User Stories

#### T4.1 Enforce TDD

| ID | Story | Priority | Status |
|----|-------|----------|--------|
| **US-4.1.1** | As a developer, I want TDD instructions embedded in each task so that teammates follow the methodology | MVP | **WORKING** |
| **US-4.1.2** | As a developer, I want the TDD skill available for direct invocation so that I can use it outside of plans | MVP | **WORKING** |

#### T4.2 Code review

| ID | Story | Priority | Status |
|----|-------|----------|--------|
| **US-4.2.1** | As a developer, I want a code-reviewer agent dispatched after plan execution so that all changes are reviewed | MVP | **WORKING** (PostPlanModeExit hook reminds) |
| **US-4.2.2** | As a developer, I want the receiving-code-review skill to process feedback so that issues are fixed properly | MVP | **WORKING** |

#### T4.3 Enforce commits

| ID | Story | Priority | Status |
|----|-------|----------|--------|
| **US-4.3.1** | As a developer, I want subagents blocked from stopping without committing so that work is not lost | Nice | **BROKEN** - `SubagentStop` hook removed |
| **US-4.3.2** | As a developer, I want a warning when stopping with active workflow so that I don't lose progress | Nice | **BROKEN** - `Stop` hook removed |

---

## 5. SESSION MANAGEMENT Activity

### User Tasks

| Task | Description |
|------|-------------|
| **T5.1** Persist state | Save workflow state for later resume |
| **T5.2** Track progress | Log events for context restoration |
| **T5.3** Manage worktrees | Create/cleanup isolated git worktrees |

### User Stories

#### T5.1 Persist state

| ID | Story | Priority | Status |
|----|-------|----------|--------|
| **US-5.1.1** | As a developer, I want workflow state in `.claude/dev-workflow-state.local.md` so that I can resume in new sessions | Critical | **BROKEN** - No state file |
| **US-5.1.2** | As a developer, I want state scoped to worktree so that parallel sessions don't conflict | Nice | **BROKEN** - No worktree awareness |
| **US-5.1.3** | As a developer, I want recovery instructions if state is corrupted so that I can fix issues | Nice | **BROKEN** - No state file |

#### T5.2 Track progress

| ID | Story | Priority | Status |
|----|-------|----------|--------|
| **US-5.2.1** | As a developer, I want progress logged with timestamps so that I can see execution history | Nice | **BROKEN** - No progress log |
| **US-5.2.2** | As a developer, I want phase summaries logged so that context can be quickly restored | Nice | **BROKEN** - No progress log |
| **US-5.2.3** | As a developer, I want `get_recent_progress` helper for resume context so that I can understand where I left off | Nice | **BROKEN** - Helper removed |

#### T5.3 Manage worktrees

| ID | Story | Priority | Status |
|----|-------|----------|--------|
| **US-5.3.1** | As a developer, I want automatic worktree creation for plan execution so that my main repo stays clean | Nice | **BROKEN** - No automatic worktree |
| **US-5.3.2** | As a developer, I want worktree cleanup after completion so that disk space is reclaimed | Nice | **BROKEN** - No worktree management |
| **US-5.3.3** | As a developer, I want `list_worktrees` to see active workspaces so that I can manage them | Nice | **BROKEN** - Helper still exists but not integrated |

---

## 6. INTEGRATION Activity

### User Tasks

| Task | Description |
|------|-------------|
| **T6.1** Finish branch | Complete work with merge/PR options |
| **T6.2** Cleanup | Remove temporary resources |

### User Stories

#### T6.1 Finish branch

| ID | Story | Priority | Status |
|----|-------|----------|--------|
| **US-6.1.1** | As a developer, I want options (Merge locally, Create PR, Keep, Discard) so that I can choose how to finish | MVP | **WORKING** |
| **US-6.1.2** | As a developer, I want tests verified before merge so that I don't break main | MVP | **WORKING** |
| **US-6.1.3** | As a developer, I want the finishing-a-development-branch skill invoked after code review so that the workflow completes | MVP | **WORKING** |

#### T6.2 Cleanup

| ID | Story | Priority | Status |
|----|-------|----------|--------|
| **US-6.2.1** | As a developer, I want worktree removed after merge so that disk space is freed | Nice | **DEGRADED** - Skill exists but no worktree to cleanup |
| **US-6.2.2** | As a developer, I want ephemeral branches cleaned up after merge so that refs stay clean | Nice | **BROKEN** - No ephemeral branches |

---

## Walking Skeleton

The minimum viable path through the system:

```
IDEATION          →  PLANNING           →  EXECUTION          →  QUALITY          →  INTEGRATION

/dev-workflow:       EnterPlanMode         ExitPlanMode          Code Review         Finish Branch
brainstorm           (explore,             (launchSwarm:         (post-swarm         (merge/PR)
(optional)           design,               true)                 action)
                     write plan)
```

**Previous version also supported:**
```
                  →  /dev-workflow:     →  /dev-workflow:     →  SubagentStop     →  Worktree
                     write-plan            execute-plan          hook                cleanup
                     (with handoff)        (with checkpoints)    (commit check)

                                        →  Resume in new       →  Stop hook
                                           session                (state warning)
```

---

## Breaking Change Impact Analysis

### Summary Statistics

| Category | Total | Working | Degraded | Broken |
|----------|-------|---------|----------|--------|
| MVP Stories | 19 | 17 | 1 | 1 |
| Nice-to-have Stories | 18 | 1 | 2 | 15 |
| Critical Stories | 2 | 0 | 0 | 2 |
| **Total** | **39** | **18** | **3** | **18** |

### Critical Breaks

| ID | Story | Impact | Decision Needed |
|----|-------|--------|-----------------|
| **US-3.4.1** | Resume execution in new session | Cannot continue work after terminal close | **UNACCEPTABLE** - Core workflow need |
| **US-5.1.1** | State persistence | No way to track progress across sessions | **UNACCEPTABLE** - Required for resume |

### Significant Breaks (Nice-to-have but high value)

| ID | Story | Impact | Decision Needed |
|----|-------|--------|-----------------|
| **US-3.3.1-3** | Batch checkpoints | Lost human-in-the-loop review during execution | Consider acceptable - swarm runs to completion |
| **US-3.2.4-6** | Ephemeral worktrees | No git isolation for parallel subagents | Consider acceptable if native swarm handles git |
| **US-4.3.1-2** | Commit enforcement hooks | Subagents can stop without committing | Consider acceptable - trust swarm behavior |
| **US-5.3.1-2** | Automatic worktree management | Main repo modified directly | Consider acceptable for simpler flow |

### Acceptable Breaks

These were nice-to-have features that added complexity without sufficient value:

- Progress logging (US-5.2.1-3) - Added token overhead
- Workflow status command (US-3.4.3) - Native tools provide equivalent
- Ephemeral branch management (US-6.2.2) - Native swarm doesn't need it

---

## Recommendations

### Must Fix (Critical)

1. **US-3.4.1 + US-5.1.1: Resume Capability**
   - The example you gave is exactly this: "execute existing plan in fresh session"
   - Without state persistence, multi-session workflows are impossible
   - **Options:**
     a. Add lightweight state file back (minimal: plan path, current task)
     b. Rely on plan file + git history to reconstruct state
     c. Accept limitation and document single-session constraint

### Should Consider (High Value)

2. **US-2.3.1: Execute Existing Plan**
   - Currently degraded: Can read plan but no dedicated command
   - Getting-started skill documents "Executing Existing Plans" but relies on same-session flow
   - **Options:**
     a. Add `/dev-workflow:execute-plan` command back (simplified)
     b. Document manual flow: Read plan → EnterPlanMode → adapt → ExitPlanMode

### Accept As-Is (Reasonable Tradeoffs)

3. **Checkpoint execution (US-3.3.x)** - Swarm runs to completion; code review happens after
4. **Ephemeral worktrees (US-3.2.4-6)** - Native swarm handles concurrency differently
5. **Commit enforcement (US-4.3.x)** - Trust native swarm behavior
6. **Progress logging (US-5.2.x)** - Reduced complexity, use git log instead

---

## User Persona Reference

| Persona | Primary Activities | Key Stories |
|---------|-------------------|-------------|
| **Solo Developer** | Ideation → Planning → Sequential Execution | US-1.x, US-2.x, US-3.1.x |
| **Power User** | Planning → Parallel Execution → Resume | US-2.x, US-3.2.x, **US-3.4.x** |
| **Team Lead** | Planning → Review → Integration | US-2.x, US-4.x, US-6.x |

The **Power User** persona is most affected by this breaking change.

---

## Migration Guide (for Power Users)

### Before (v1.x)
```bash
# Session 1: Create plan
/dev-workflow:write-plan "Add authentication"
# → Saves plan, creates worktree

# Session 2: Execute (next day)
/dev-workflow:execute-plan docs/plans/2025-12-14-auth.md
# → Resumes from state file, continues where left off

# Session 3: Handle interruption
/dev-workflow:workflow-status
# → Shows progress, offers Continue/Reset
```

### After (v2.x - current)
```bash
# Session 1: Plan and execute in one go
/dev-workflow:brainstorm "Add authentication"  # Optional
# → User selects "Create plan"
EnterPlanMode
# → Explore, design, write plan
ExitPlanMode(launchSwarm: true, teammateCount: 3)
# → Swarm executes to completion
# → Code review (PostPlanModeExit reminder)
# → Finish branch

# Cannot resume in Session 2 - must complete in Session 1
```

### For Existing Plans
```bash
# Read the plan
Read("docs/plans/2025-12-14-auth.md")

# Ask user how to execute (described in getting-started skill)
# Option A: Sequential - execute in current session
# Option B: Parallel - EnterPlanMode, adapt plan, ExitPlanMode(launchSwarm: true)
```

---

## Appendix: Removed Components

| Component | Lines | Purpose |
|-----------|-------|---------|
| `commands/execute-plan.md` | 611 | Batch execution with checkpoints |
| `commands/write-plan.md` | 291 | Plan creation command |
| `skills/subagent-driven-development/SKILL.md` | 619 | Anthropic multi-agent pattern |
| `references/state-format.md` | 350 | State file documentation |
| `hooks/check-state-on-stop.sh` | 29 | Stop warning hook |
| `hooks/check-commit-on-subagent-stop.sh` | 58 | Subagent commit enforcement |
| **Total removed** | **~1,958** | |

| Component | Lines | Purpose |
|-----------|-------|---------|
| Getting-started skill additions | ~140 | Planning methodology |
| PostPlanModeExit hook | 25 | Post-swarm reminder |
| **Total added** | **~165** | |

**Net reduction: ~1,793 lines of orchestration code**
