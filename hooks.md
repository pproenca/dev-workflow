  All Hook Event Types

  | Event             | Description                                  |
  |-------------------|----------------------------------------------|
  | PreToolUse        | Before a tool executes                       |
  | PostToolUse       | After a tool completes                       |
  | Notification      | When Claude sends a notification             |
  | Stop              | When Claude finishes a response              |
  | SessionStart      | When a new session begins                    |
  | UserPromptSubmit  | When user submits a prompt before processing |
  | PrePlanModeEnter  | Before entering plan mode                    |
  | PostPlanModeEnter | After entering plan mode                     |
  | PrePlanModeExit   | Before exiting plan mode                     |
  | PostPlanModeExit  | After exiting plan mode                      |

  Full Hook Schema

  {
    "hooks": {
      "<EventType>": [
        {
          "matcher": "<pattern>",       // Tool name pattern (string - glob/regex)
          "command": "<cmd>" | ["cmd", "arg1"],  // Shell command (string or array)
          "timeout": 10000,             // Timeout in ms (optional)
          "environment": {              // Extra env vars (optional)
            "KEY": "value"
          }
        }
      ]
    }
  }

  Matcher Patterns

  For PreToolUse and PostToolUse, the matcher field supports:

  | Pattern             | Example           | Matches                         |
  |---------------------|-------------------|---------------------------------|
  | Exact               | "Bash"            | Only Bash tool                  |
  | Glob                | "Bash(*)"         | Bash with any subcommand        |
  | Glob                | "Bash(git*)"      | Bash commands starting with git |
  | Glob                | "*"               | All tools                       |
  | Specific subcommand | "Bash(rm:*)"      | Bash rm commands                |
  | Multiple patterns   | ["Bash", "Write"] | Either Bash or Write            |

  Environment Variables Passed to Hooks

  All hooks:
  - CLAUDE_EVENT_TYPE - The event type
  - CLAUDE_SESSION_ID - Session identifier
  - CLAUDE_WORKING_DIRECTORY - Current working directory

  Tool hooks (PreToolUse/PostToolUse):
  - CLAUDE_TOOL_NAME - Tool name (e.g., Bash, Write)
  - CLAUDE_TOOL_INPUT - JSON string of tool input parameters

  PostToolUse only:
  - CLAUDE_TOOL_OUTPUT - JSON string of tool output/result

  UserPromptSubmit:
  - CLAUDE_USER_PROMPT - The user's prompt text

  Plan mode hooks:
  - CLAUDE_PLAN_FILE - Path to the plan file (if applicable)

  Hook Return Behavior

  | Exit Code | stdout | Behavior                                   |
  |-----------|--------|--------------------------------------------|
  | 0         | empty  | Continue normally                          |
  | 0         | text   | Continue, text shown to Claude as feedback |
  | 2         | empty  | Block the action                           |
  | 2         | text   | Block with reason shown to Claude          |
  | Other     | any    | Error logged, continues                    |

  Command Formats

  // Simple string
  "command": "bash /path/to/script.sh"

  // Array (avoids shell escaping issues)
  "command": ["python", "/path/to/script.py", "--flag"]

  // With arguments referencing env vars
  "command": "echo $CLAUDE_TOOL_NAME >> /tmp/log.txt"

  Complete Example

  {
    "hooks": {
      "SessionStart": [
        {
          "command": ["bash", "-c", "echo 'Session started' >> ~/.claude/session.log"]
        }
      ],
      "UserPromptSubmit": [
        {
          "command": "python ~/.claude/hooks/enrich-prompt.py",
          "timeout": 5000
        }
      ],
      "PreToolUse": [
        {
          "matcher": "Bash(rm:*)",
          "command": "bash ~/.claude/hooks/confirm-delete.sh",
          "timeout": 3000
        },
        {
          "matcher": "Bash(git push:*)",
          "command": ["bash", "~/.claude/hooks/pre-push-check.sh"]
        },
        {
          "matcher": "Write",
          "command": "python ~/.claude/hooks/validate-write.py"
        }
      ],
      "PostToolUse": [
        {
          "matcher": "Bash(git commit:*)",
          "command": "bash ~/.claude/hooks/post-commit.sh"
        }
      ],
      "PrePlanModeEnter": [
        {
          "command": "echo 'Entering plan mode...'"
        }
      ],
      "PostPlanModeExit": [
        {
          "command": "bash ~/.claude/hooks/plan-complete.sh"
        }
      ],
      "Stop": [
        {
          "command": "bash ~/.claude/hooks/on-stop.sh"
        }
      ]
    }
  }