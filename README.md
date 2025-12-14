# dev-workflow

Structured development workflow for Claude Code. Enforces TDD, systematic debugging, and verification.

```mermaid
flowchart LR
    subgraph entry["Entry Points"]
        B["/brainstorm"]
        P["EnterPlanMode"]
    end

    subgraph artifacts["Artifacts"]
        DD["design-doc.md"]
        PF["plan.md"]
    end

    subgraph execution["Execution"]
        SWARM["Swarm execution"]
    end

    B -->|"Socratic dialogue"| DD
    DD -->|"input"| P
    P -->|"explore + design"| PF
    PF -->|"ExitPlanMode(launchSwarm)"| SWARM
    SWARM --> DONE["Done"]
```

## Why This Plugin

Most plugins add capabilities. This one changes how you work.

**The problem:** Claude is capable but undisciplined. It skips tests, claims "should work now" without verification, fixes symptoms instead of root causes, and accumulates context until it loses track.

**The solution:** A workflow system that enforces discipline through architecture:

| Problem | Solution |
|---------|----------|
| Context pollution | Native swarm execution |
| "Should work now" | Verification before any claim |
| Symptom patching | Systematic debugging framework |
| Skipped tests | TDD as methodology, not suggestion |

## Architecture

Built on Claude Code primitives:

```
SessionStart hook
    └── Loads getting-started skill with planning methodology

EnterPlanMode / ExitPlanMode
    └── Native plan mode for design + swarm execution

PostPlanModeExit hook
    └── Reminds of post-swarm actions (code review, finish branch)
```

**Token efficiency:**
- Skills loaded on-demand via triggers
- Native swarm handles parallel execution
- Model selection per task complexity

## Features

### Skills (11)

| Category | Skills |
|----------|--------|
| Methodology | `test-driven-development`, `systematic-debugging`, `root-cause-tracing` |
| Quality | `verification-before-completion`, `testing-anti-patterns`, `defense-in-depth` |
| Collaboration | `receiving-code-review` |
| Workflow | `finishing-a-development-branch` |
| Session | `getting-started`, `condition-based-waiting`, `pragmatic-architecture` |

**Rigid skills** (follow exactly): TDD, debugging, verification
**Flexible skills** (adapt principles): brainstorming, architecture

### Commands

| Command | Purpose |
|---------|---------|
| `/dev-workflow:brainstorm` | Refine idea → design doc |

### Agents

| Agent | Purpose |
|-------|---------|
| `code-explorer` | Survey codebase for context |
| `code-architect` | Design implementation approach |
| `code-reviewer` | Review completed work |

## Installation

```bash
claude plugin add pproenca/dev-workflow
```

Or:

```bash
git clone https://github.com/pproenca/dev-workflow ~/.claude/plugins/dev-workflow
```

## Prerequisites

**Required:** `git`
**Optional:** `jq`, `bats-core`, `shellcheck`, `pre-commit`

## Usage

Skills load automatically at session start. The `getting-started` skill establishes the protocol: before any task, check if a skill applies.

State persists in `.claude/dev-workflow-state.local.md`. Sessions can crash and resume.

## Development

```bash
./scripts/setup.sh       # Contributor setup
./scripts/validate.sh    # Full validation
bats tests/              # Test suite
```

## Acknowledgments

Inspired by:

- [anthropics/claude-code](https://github.com/anthropics/claude-code)
- [anthropics/skills](https://github.com/anthropics/skills)
- [obra/superpowers](https://github.com/obra/superpowers)

## License

MIT
