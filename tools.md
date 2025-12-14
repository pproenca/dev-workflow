# Native Tools Reference

Complete reference for all tools available to Claude Code, extracted from system configuration.

---

## 1. Task

**Description:** Launch specialized agents (subprocesses) for complex, multi-step tasks autonomously.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `prompt` | string | Yes | The task for the agent to perform |
| `description` | string | Yes | A short (3-5 word) description of the task |
| `subagent_type` | string | Yes | The type of specialized agent to use |
| `model` | enum | No | `sonnet`, `opus`, or `haiku` - model to use (inherits from parent if not specified) |
| `resume` | string | No | Agent ID to resume from a previous invocation (continues with full previous context) |
| `run_in_background` | boolean | No | Run agent in background, retrieve results with TaskOutput |

**Available Agent Types:**
| Type | Description | Tools |
|------|-------------|-------|
| `general-purpose` | Research, code search, multi-step tasks | All tools |
| `statusline-setup` | Configure status line settings | Read, Edit |
| `Explore` | Fast codebase exploration. Specify thoroughness: "quick", "medium", "very thorough" | All tools |
| `Plan` | Software architect for designing implementation plans | All tools |
| `claude-code-guide` | Questions about Claude Code features, Agent SDK, Claude API | Glob, Grep, Read, WebFetch, WebSearch |
| `dev-workflow:code-reviewer` | Code review agent | Glob, Grep, LS, Read, Bash |
| `dev-workflow:code-explorer` | Code exploration agent | Glob, Grep, LS, Read |
| `dev-workflow:code-architect` | Architecture agent | Glob, Grep, LS, Read, NotebookRead, WebFetch, TodoWrite, WebSearch |

**Usage Notes:**
- Launch multiple agents concurrently in a single message when no dependencies exist
- Agent results are not visible to user - summarize results in your response
- Use `resume` with agent ID to continue previous work with full context preserved
- Agents with "access to current context" can see full conversation history

---

## 2. TaskOutput

**Description:** Retrieves output from a running or completed task (background shell, agent, or remote session).

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `task_id` | string | Yes | - | The task ID to get output from |
| `block` | boolean | No | `true` | Whether to wait for task completion |
| `timeout` | number | No | 30000 | Max wait time in ms (max: 600000) |

**Usage Notes:**
- Use `block=true` (default) to wait for task completion
- Use `block=false` for non-blocking status check
- Works with all task types: background shells, async agents, remote sessions
- Find task IDs using `/tasks` command

---

## 3. Bash

**Description:** Executes bash commands in a persistent shell session with optional timeout.

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `command` | string | Yes | - | The command to execute |
| `description` | string | No | - | Clear, concise description (5-10 words) in active voice |
| `timeout` | number | No | 120000 | Timeout in milliseconds (max: 600000) |
| `run_in_background` | boolean | No | `false` | Run command in background |
| `dangerouslyDisableSandbox` | boolean | No | `false` | Override sandbox mode |

**Usage Notes:**
- Output truncated at 30000 characters
- Always quote paths with spaces using double quotes
- Use `&&` to chain dependent commands, `;` for sequential-regardless-of-failure
- Prefer absolute paths over `cd`
- DO NOT use for file operations (use Read, Edit, Write, Glob, Grep instead)
- DO NOT use `find`, `grep`, `cat`, `head`, `tail`, `sed`, `awk`, `echo` for file operations

**Auto-Approved Commands:**
```
find, rg, echo, grep, ls, cat, sed, source, mkdir, pgrep
git (branch, diff, status, rev-parse, log, fetch, worktree, add, remote)
gh (pr list, pr view, pr diff, api user, repo view, issue view)
npm, yarn, pnpm, npx, python, uv, ruff, bash
```

**Git Commit Protocol:**
1. Run `git status`, `git diff`, `git log` in parallel
2. Analyze changes, draft commit message (focus on "why")
3. Stage files, create commit, verify with `git status`
4. Use HEREDOC for commit messages:
```bash
git commit -m "$(cat <<'EOF'
Commit message here.
EOF
)"
```

**Git Safety Rules:**
- NEVER update git config
- NEVER run destructive commands (push --force, hard reset) unless explicitly requested
- NEVER skip hooks (--no-verify) unless explicitly requested
- NEVER use -i flag (interactive mode not supported)
- Avoid `git commit --amend` unless explicitly requested or adding pre-commit hook edits

---

## 4. Glob

**Description:** Fast file pattern matching tool that works with any codebase size.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `pattern` | string | Yes | Glob pattern to match (e.g., `**/*.js`, `src/**/*.ts`) |
| `path` | string | No | Directory to search in (defaults to cwd). Omit for default - do NOT use "undefined" or "null" |

**Usage Notes:**
- Returns matching file paths sorted by modification time
- Use for finding files by name patterns
- For open-ended searches requiring multiple rounds, use Task tool with Explore agent instead
- Run multiple speculative searches in parallel when potentially useful

---

## 5. Grep

**Description:** Powerful search tool built on ripgrep for searching file contents.

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `pattern` | string | Yes | - | Regular expression pattern to search for |
| `path` | string | No | cwd | File or directory to search in |
| `glob` | string | No | - | Glob pattern to filter files (e.g., `*.js`, `*.{ts,tsx}`) |
| `type` | string | No | - | File type to search (e.g., `js`, `py`, `rust`, `go`) |
| `output_mode` | enum | No | `files_with_matches` | `content`, `files_with_matches`, or `count` |
| `-A` | number | No | - | Lines to show after each match (requires `output_mode: content`) |
| `-B` | number | No | - | Lines to show before each match (requires `output_mode: content`) |
| `-C` | number | No | - | Lines to show before and after each match (requires `output_mode: content`) |
| `-i` | boolean | No | - | Case insensitive search |
| `-n` | boolean | No | `true` | Show line numbers (for content mode) |
| `multiline` | boolean | No | `false` | Enable multiline mode where `.` matches newlines |
| `head_limit` | number | No | 0 | Limit output to first N lines/entries (0 = unlimited) |
| `offset` | number | No | 0 | Skip first N lines/entries |

**Usage Notes:**
- Uses ripgrep syntax (not grep) - literal braces need escaping: `interface\{\}` to find `interface{}`
- For cross-line patterns like `struct \{[\s\S]*?field`, use `multiline: true`
- NEVER use `grep` or `rg` as Bash commands - always use this Grep tool

---

## 6. Read

**Description:** Reads a file from the local filesystem.

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `file_path` | string | Yes | - | Absolute path to the file to read |
| `offset` | number | No | - | Line number to start reading from |
| `limit` | number | No | 2000 | Number of lines to read |

**Supported Formats:**
- Text files (code, config, etc.)
- Images (PNG, JPG, etc.) - presented visually
- PDF files - page by page extraction
- Jupyter notebooks (.ipynb) - all cells with outputs

**Usage Notes:**
- Line numbers start at 1, output uses `cat -n` format
- Lines longer than 2000 characters are truncated
- Can only read files, not directories (use `ls` via Bash for directories)
- Run multiple speculative reads in parallel
- Screenshots and temporary file paths are supported

---

## 7. Edit

**Description:** Performs exact string replacements in files.

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `file_path` | string | Yes | - | Absolute path to the file to modify |
| `old_string` | string | Yes | - | The text to replace |
| `new_string` | string | Yes | - | The text to replace it with (must be different from old_string) |
| `replace_all` | boolean | No | `false` | Replace all occurrences |

**Usage Notes:**
- MUST Read file first before editing
- Edit FAILS if `old_string` is not unique - provide more context or use `replace_all`
- Preserve exact indentation from file content (not line number prefix)
- Use `replace_all` for renaming variables across the file
- Prefer editing existing files over creating new ones
- Only use emojis if user explicitly requests them

---

## 8. Write

**Description:** Writes a file to the local filesystem.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `file_path` | string | Yes | Absolute path to the file to write |
| `content` | string | Yes | The content to write to the file |

**Usage Notes:**
- Overwrites existing files
- MUST Read existing files first before overwriting
- Prefer editing existing files over creating new ones
- NEVER proactively create documentation files (*.md) or README files unless explicitly requested
- Only use emojis if user explicitly requests them

---

## 9. NotebookEdit

**Description:** Replaces contents of a specific cell in a Jupyter notebook (.ipynb file).

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `notebook_path` | string | Yes | - | Absolute path to the Jupyter notebook |
| `new_source` | string | Yes | - | The new source for the cell |
| `cell_id` | string | No | - | ID of the cell to edit. For insert mode, new cell inserted after this ID |
| `cell_type` | enum | No | current type | `code` or `markdown`. Required for insert mode |
| `edit_mode` | enum | No | `replace` | `replace`, `insert`, or `delete` |

---

## 10. WebFetch

**Description:** Fetches content from a URL and processes it using an AI model.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `url` | string (uri) | Yes | The URL to fetch content from |
| `prompt` | string | Yes | The prompt to run on the fetched content |

**Usage Notes:**
- HTTP URLs automatically upgraded to HTTPS
- 15-minute self-cleaning cache for repeated access
- HTML converted to markdown before processing
- Results may be summarized if content is very large
- If redirect to different host, make new WebFetch request with provided redirect URL
- If MCP-provided web fetch tool is available, prefer that instead

---

## 11. WebSearch

**Description:** Search the web and use results to inform responses.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `query` | string (minLength: 2) | Yes | The search query to use |
| `allowed_domains` | string[] | No | Only include results from these domains |
| `blocked_domains` | string[] | No | Never include results from these domains |

**Usage Notes:**
- Only available in the US
- MUST include "Sources:" section with URLs in response after using:
```
[Your answer here]

Sources:
- [Source Title 1](https://example.com/1)
- [Source Title 2](https://example.com/2)
```
- Use current year (2025) in search queries for recent information

---

## 12. TodoWrite

**Description:** Create and manage a structured task list for the current coding session.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `todos` | array | Yes | The updated todo list |

**Todo Item Schema:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `content` | string (minLength: 1) | Yes | Imperative form (e.g., "Run tests", "Fix bug") |
| `activeForm` | string (minLength: 1) | Yes | Present continuous form (e.g., "Running tests", "Fixing bug") |
| `status` | enum | Yes | `pending`, `in_progress`, or `completed` |

**When to Use:**
- Complex multi-step tasks (3+ distinct steps)
- Non-trivial and complex tasks requiring planning
- User explicitly requests todo list
- User provides multiple tasks (numbered or comma-separated)
- After receiving new instructions
- When starting a task (mark as `in_progress`)
- After completing a task (mark as `completed`)

**When NOT to Use:**
- Single, straightforward task
- Trivial tasks with tracking providing no benefit
- Task completable in less than 3 trivial steps
- Purely conversational or informational tasks

**Rules:**
- Only ONE task should be `in_progress` at any time
- Mark tasks complete IMMEDIATELY after finishing (don't batch)
- Only mark `completed` when FULLY accomplished (not if errors, blockers, partial implementation)
- Remove irrelevant tasks entirely

---

## 13. AskUserQuestion

**Description:** Ask the user questions during execution to gather preferences, clarify instructions, or get decisions.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `questions` | array (1-4 items) | Yes | Questions to ask |

**Question Schema:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `question` | string | Yes | Complete question ending with `?`. If multiSelect, phrase accordingly |
| `header` | string (max 12 chars) | Yes | Short label (e.g., "Auth method", "Library") |
| `options` | array (2-4 items) | Yes | Available choices |
| `multiSelect` | boolean | Yes | Allow multiple selections |

**Option Schema:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `label` | string (1-5 words) | Yes | Display text for the choice |
| `description` | string | Yes | Explanation of what this option means |

**Usage Notes:**
- Users can always select "Other" for custom input
- If recommending a specific option, make it first and add "(Recommended)" to label

---

## 14. EnterPlanMode

**Description:** Transitions into plan mode to design implementation approach for user approval before writing code.

**Parameters:** None (empty object)

**When to Use:**
- New feature implementation
- Multiple valid approaches exist
- Code modifications affecting existing behavior
- Architectural decisions required
- Multi-file changes (more than 2-3 files)
- Unclear requirements needing exploration
- User preferences matter for implementation direction

**When NOT to Use:**
- Single-line or few-line fixes
- Adding a single function with clear requirements
- User gave very specific, detailed instructions
- Pure research/exploration tasks (use Task with Explore agent)

**What Happens in Plan Mode:**
1. Explore codebase using Glob, Grep, Read
2. Understand existing patterns and architecture
3. Design implementation approach
4. Present plan to user for approval
5. Use AskUserQuestion if needed to clarify approaches
6. Exit with ExitPlanMode when ready to implement

---

## 15. ExitPlanMode

**Description:** Signal that you've finished writing your plan and are ready for user approval.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `launchSwarm` | boolean | No | Whether to launch a swarm to implement the plan |
| `teammateCount` | number | No | Number of teammates to spawn in the swarm |

**Usage Notes:**
- Only use when planning implementation steps for code-writing tasks
- Do NOT use for research tasks (gathering information, searching/reading files)
- Ensure plan is clear and unambiguous before using
- If multiple valid approaches exist, use AskUserQuestion first to clarify

---

## 16. KillShell

**Description:** Kills a running background bash shell by its ID.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `shell_id` | string | Yes | The ID of the background shell to kill |

**Usage Notes:**
- Find shell IDs using `/tasks` command

---

## 17. Skill

**Description:** Execute a skill within the main conversation.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `skill` | string | Yes | The skill name (no arguments), e.g., "pdf" or "xlsx" |

**Usage Notes:**
- When a skill is relevant, invoke this tool IMMEDIATELY as first action
- NEVER just announce a skill without calling this tool
- Only use skills listed in Available Skills
- Do not invoke a skill that is already running
- Do not use for built-in CLI commands

---

## 18. SlashCommand

**Description:** Execute a slash command within the main conversation.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `command` | string | Yes | The slash command with arguments (e.g., `/review-pr 123`) |

**Usage Notes:**
- Only use for custom slash commands in Available Commands list
- Do NOT use for built-in CLI commands (like /help, /clear)
- When user requests multiple slash commands, execute sequentially
- Check for `<command-message>{name} is running…</command-message>` to verify processing
- Do not invoke a command that is already running

---

## MCP Tools

### 19. mcp__ide__getDiagnostics

**Description:** Get language diagnostics from VS Code.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `uri` | string | No | File URI to get diagnostics for. If not provided, gets diagnostics for all files |

---

### 20. mcp__ide__executeCode

**Description:** Execute Python code in the Jupyter kernel for the current notebook file.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `code` | string | Yes | The code to execute on the kernel |

**Usage Notes:**
- Code executes in current Jupyter kernel
- Avoid declaring variables or modifying kernel state unless explicitly asked
- Executed code persists across calls unless kernel restarted

---

### 21. mcp__context7__resolve-library-id

**Description:** Resolves a package/product name to a Context7-compatible library ID.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `libraryName` | string | Yes | Library name to search for |

**Usage Notes:**
- MUST call this before `get-library-docs` to obtain valid library ID
- UNLESS user explicitly provides library ID in format `/org/project` or `/org/project/version`
- Returns list of matching libraries with selection guidance

---

### 22. mcp__context7__get-library-docs

**Description:** Fetches up-to-date documentation for a library.

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `context7CompatibleLibraryID` | string | Yes | - | Exact library ID (e.g., `/mongodb/docs`, `/vercel/next.js`) |
| `topic` | string | No | - | Topic to focus on (e.g., "hooks", "routing") |
| `mode` | enum | No | `code` | `code` for API references/examples, `info` for conceptual guides |
| `page` | integer (1-10) | No | 1 | Page number for pagination |

**Usage Notes:**
- Must call `resolve-library-id` first unless user provides library ID directly
- If context insufficient, try page=2, page=3, etc. with same topic
