# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Claude Code plugin enforcing TDD, systematic debugging, and code review. Skills load at session start via `SessionStart` hook.

## Commands

```bash
./scripts/validate.sh              # Full validation (JSON, permissions, frontmatter, shellcheck)
./scripts/setup.sh                 # Contributor setup (bats, pre-commit)
bats tests/                        # Run all tests
bats tests/session-start.bats     # Run single test file
```

Tests run on commit via pre-commit hook.

## Architecture

**Plugin flow:**
```
/dev-workflow:brainstorm → /dev-workflow:write-plan → execute
                                                       ├─ "Execute now" → subagent-driven-development
                                                       └─ "Batch execution" → /dev-workflow:execute-plan
```

**Hooks** (`hooks/hooks.json`):
- `SessionStart` → loads getting-started skill
- `Stop` → warns on incomplete workflow
- `SubagentStop` → verifies commit after task

**State**: Workflows persist to `.claude/dev-workflow-state.local.md` (worktree-scoped). See `references/state-format.md`.

**Helper functions**: `scripts/hook-helpers.sh` provides `frontmatter_get`/`frontmatter_set` for safe YAML parsing.

## Component Frontmatter

All components require YAML frontmatter.

**Valid tools:** `Read`, `Write`, `Edit`, `Bash`, `Glob`, `Grep`, `Task`, `TodoWrite`, `AskUserQuestion`, `Skill`, `WebFetch`, `WebSearch`, `NotebookRead`, `NotebookEdit`, `LS`

**Skills** (`skills/<name>/SKILL.md`):
```yaml
---
name: skill-name
description: Trigger phrases for skill discovery
allowed-tools: [Read, Edit, Bash]
---
```

**Commands** (`commands/<name>.md`):
```yaml
---
description: What the command does
allowed-tools: [Read, Task, TodoWrite]
---
```

**Agents** (`agents/<name>.md`):
```yaml
---
name: agent-name
description: When to dispatch via Task tool
model: sonnet | haiku
tools: [Glob, Grep, Read]
---
```

## Skill Categories

| Category | Skills | Execution |
|----------|--------|-----------|
| Rigid | TDD, systematic-debugging, verification-before-completion | Follow exactly |
| Flexible | brainstorm, architecture | Adapt to context |

Skills with checklists require TodoWrite tracking.

## Directory Structure

```
hooks/           # Event handlers (SessionStart, Stop, SubagentStop)
scripts/         # Validation, setup, helpers
skills/          # SKILL.md per skill with optional references/
commands/        # Slash commands (/dev-workflow:*)
agents/          # Subagent definitions
references/      # Shared docs (state-format, skill-integration)
tests/           # Bats tests for hooks and scripts
```

## References

- `references/skill-integration.md` — Decision trees, skill chains, trigger patterns
- `references/state-format.md` — State file format, helper functions
- `references/planning-philosophy.md` — Planning approach

## Dependencies

**Required:** `git`
**Optional:** `jq`, `bats-core`, `shellcheck`, `pre-commit`
