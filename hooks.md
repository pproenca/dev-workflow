# Claude Code Hooks Reference

Complete reference for all hooks available in Claude Code.

---

## Overview

Hooks are shell commands that execute in response to events during Claude Code execution. They can intercept, modify, or block operations.

**Key Behavior:**
- Feedback from hooks (including `<user-prompt-submit-hook>`) is treated as coming from the user
- If blocked by a hook, Claude will determine if it can adjust actions based on the blocked message
- If adjustment isn't possible, Claude will ask the user to check their hooks configuration

---

## All Hook Event Types

| Event | Description |
|-------|-------------|
| `SessionStart` | When a new session begins |
| `SessionEnd` | When a session ends |
| `UserPromptSubmit` | When user submits a prompt before processing |
| `PreToolUse` | Before a tool executes |
| `PostToolUse` | After a tool completes successfully |
| `Notification` | When Claude sends a notification |
| `Stop` | When Claude finishes a response |
| `SubagentStart` | When a subagent (spawned via Task tool) starts |
| `SubagentStop` | When a subagent completes |
| `PreCompact` | Before context compaction |
| `PermissionRequest` | When permission is requested |

---

## Event Details

### SessionStart

**Trigger:** When a new Claude Code session begins.

**Use Cases:**
- Load initial context or skills
- Set up environment variables
- Display welcome messages
- Initialize session state

---

### SessionEnd

**Trigger:** When a Claude Code session ends.

**Use Cases:**
- Cleanup temporary files
- Save session state
- Log session summary

---

### UserPromptSubmit

**Trigger:** When user submits a prompt (before processing).

**Use Cases:**
- Validate user input
- Augment prompts with context
- Block certain request types
- Inject system reminders

**Note:** Feedback appears as `<user-prompt-submit-hook>` and is treated as user input.

---

### PreToolUse

**Trigger:** Before any tool is executed.

**Use Cases:**
- Validate tool parameters
- Block dangerous operations
- Log tool usage
- Transform tool inputs
- Require confirmations

**Available Context:**
- Tool name being called
- Tool parameters (via `CLAUDE_TOOL_INPUT`)

---

### PostToolUse

**Trigger:** After a tool completes execution successfully.

**Use Cases:**
- Log tool results
- Transform tool outputs
- Trigger follow-up actions
- Collect metrics

**Available Context:**
- Tool name, input, and output

---

### Notification

**Trigger:** When Claude sends a notification.

**Use Cases:**
- Custom notification handling
- External alerting systems
- Log notifications

---

### Stop

**Trigger:** When Claude finishes a response.

**Use Cases:**
- Save session state
- Cleanup temporary files
- Log session summary
- Run final validation

---

### SubagentStart

**Trigger:** When a subagent (spawned via Task tool) starts.

**Use Cases:**
- Log subagent start
- Initialize subagent context
- Track active subagents

---

### SubagentStop

**Trigger:** When a subagent (spawned via Task tool) completes.

**Use Cases:**
- Process subagent results
- Trigger follow-up actions
- Log subagent completion
- Validate subagent output

---

### PreCompact

**Trigger:** Before context compaction occurs.

**Use Cases:**
- Save important context
- Log compaction events

---

### PermissionRequest

**Trigger:** When permission is requested for an action.

**Use Cases:**
- Custom permission handling
- Auto-approve patterns
- Log permission requests

---

## Full Hook Schema

```json
{
  "hooks": {
    "<EventType>": [
      {
        "matcher": "<pattern>",
        "hooks": [
          {
            "type": "command",
            "command": "<cmd>",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

### Hook Properties

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `matcher` | string | No | `"*"` | Pattern to match (tool name for tool hooks) |
| `type` | string | Yes | - | Hook type (usually `"command"`) |
| `command` | string | Yes | - | Shell command to execute |
| `timeout` | number | No | 10 | Timeout in seconds |

---

## Matcher Patterns

For `PreToolUse` and `PostToolUse`, the `matcher` field supports:

| Pattern | Example | Matches |
|---------|---------|---------|
| Exact | `"Bash"` | Only Bash tool |
| Glob | `"Bash(*)"` | Bash with any subcommand |
| Glob | `"Bash(git*)"` | Bash commands starting with git |
| Glob | `"*"` | All tools |
| Specific subcommand | `"Bash(rm:*)"` | Bash rm commands |

---

## Environment Variables Passed to Hooks

### All Hooks

| Variable | Description |
|----------|-------------|
| `CLAUDE_EVENT_TYPE` | The event type |
| `CLAUDE_SESSION_ID` | Session identifier |
| `CLAUDE_WORKING_DIRECTORY` | Current working directory |
| `CLAUDE_PLUGIN_ROOT` | Plugin root directory |

### Tool Hooks (PreToolUse/PostToolUse)

| Variable | Description |
|----------|-------------|
| `CLAUDE_TOOL_NAME` | Tool name (e.g., Bash, Write) |
| `CLAUDE_TOOL_INPUT` | JSON string of tool input parameters |

### PostToolUse Only

| Variable | Description |
|----------|-------------|
| `CLAUDE_TOOL_OUTPUT` | JSON string of tool output/result |

### UserPromptSubmit

| Variable | Description |
|----------|-------------|
| `CLAUDE_USER_PROMPT` | The user's prompt text |

---

## Hook Return Behavior

| Exit Code | stdout | Behavior |
|-----------|--------|----------|
| 0 | empty | Continue normally |
| 0 | JSON | Continue, JSON shown to Claude as feedback |
| 2 | empty | Block the action |
| 2 | JSON | Block with reason shown to Claude |
| Other | any | Error logged, continues |

---

## Complete Example

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh\"",
            "timeout": 5
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash(rm:*)",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/confirm-delete.sh",
            "timeout": 3
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash(git commit:*)",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/post-commit.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/process-subagent.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

---

## Best Practices

1. **Keep hooks fast** - Long-running hooks slow down interaction
2. **Handle errors gracefully** - Provide clear error messages in stdout
3. **Test thoroughly** - Hooks can break workflows if misconfigured
4. **Log judiciously** - Don't spam with unnecessary output
5. **Set appropriate timeouts** - Ensure hooks complete within timeout
6. **Use exit code 2 for blocking** - Provides clear feedback to Claude

---

## Plugin-Specific Hooks (dev-workflow)

This plugin uses the following hooks:

| Hook | Purpose |
|------|---------|
| `SessionStart` | Loads getting-started skill with planning methodology |

See `hooks/hooks.json` for the actual implementation.
