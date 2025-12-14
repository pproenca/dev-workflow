  1. Task

  Description: Launch specialized agents (subprocesses) for complex, multi-step tasks autonomously.

  Parameters:
  - prompt (required, string): The task for the agent to perform
  - description (required, string): A short (3-5 word) description of the task
  - subagent_type (required, string): The type of specialized agent to use
  - model (optional, enum): sonnet, opus, or haiku - model to use for the agent
  - resume (optional, string): Agent ID to resume from a previous invocation
  - run_in_background (optional, boolean): Run agent in background, retrieve results with TaskOutput

  Available Agent Types:
  - general-purpose: Research, code search, multi-step tasks
  - statusline-setup: Configure status line settings
  - Explore: Fast codebase exploration (specify thoroughness: "quick", "medium", "very thorough")
  - Plan: Software architect for designing implementation plans
  - claude-code-guide: Questions about Claude Code features, Agent SDK, Claude API
  - dev-workflow:code-reviewer: Code review agent
  - dev-workflow:code-explorer: Code exploration agent
  - dev-workflow:code-architect: Architecture agent

  ---
  2. TaskOutput

  Description: Retrieves output from a running or completed task (background shell, agent, or remote session).

  Parameters:
  - task_id (required, string): The task ID to get output from
  - block (optional, boolean, default: true): Whether to wait for task completion
  - timeout (optional, number, default: 30000, max: 600000): Max wait time in ms

  ---
  3. Bash

  Description: Executes bash commands in a persistent shell session with optional timeout.

  Parameters:
  - command (required, string): The command to execute
  - description (optional, string): Clear, concise description (5-10 words) of what the command does
  - timeout (optional, number, max: 600000): Timeout in milliseconds (default: 120000)
  - run_in_background (optional, boolean): Run command in background
  - dangerouslyDisableSandbox (optional, boolean): Override sandbox mode

  Notes: Max output 30000 chars (truncated). Prefer dedicated tools for file operations.

  ---
  4. Glob

  Description: Fast file pattern matching tool that works with any codebase size.

  Parameters:
  - pattern (required, string): The glob pattern to match files against (e.g., **/*.js, src/**/*.ts)
  - path (optional, string): Directory to search in (defaults to current working directory)

  Notes: Returns matching file paths sorted by modification time.

  ---
  5. Grep

  Description: Powerful search tool built on ripgrep for searching file contents.

  Parameters:
  - pattern (required, string): Regular expression pattern to search for
  - path (optional, string): File or directory to search in
  - glob (optional, string): Glob pattern to filter files (e.g., *.js, *.{ts,tsx})
  - type (optional, string): File type to search (e.g., js, py, rust, go)
  - output_mode (optional, enum): content, files_with_matches (default), or count
  - -A (optional, number): Lines to show after each match
  - -B (optional, number): Lines to show before each match
  - -C (optional, number): Lines to show before and after each match
  - -i (optional, boolean): Case insensitive search
  - -n (optional, boolean): Show line numbers (default: true for content mode)
  - multiline (optional, boolean): Enable multiline mode where . matches newlines
  - head_limit (optional, number): Limit output to first N lines/entries
  - offset (optional, number): Skip first N lines/entries

  ---
  6. Read

  Description: Reads a file from the local filesystem.

  Parameters:
  - file_path (required, string): Absolute path to the file to read
  - offset (optional, number): Line number to start reading from
  - limit (optional, number): Number of lines to read

  Notes:
  - Reads up to 2000 lines by default
  - Lines longer than 2000 chars are truncated
  - Can read images (PNG, JPG), PDFs, and Jupyter notebooks (.ipynb)
  - Results use cat -n format with line numbers starting at 1

  ---
  7. Edit

  Description: Performs exact string replacements in files.

  Parameters:
  - file_path (required, string): Absolute path to the file to modify
  - old_string (required, string): The text to replace
  - new_string (required, string): The text to replace it with (must be different)
  - replace_all (optional, boolean, default: false): Replace all occurrences

  Notes:
  - Must Read file first before editing
  - Edit fails if old_string is not unique (use more context or replace_all)

  ---
  8. Write

  Description: Writes a file to the local filesystem.

  Parameters:
  - file_path (required, string): Absolute path to the file (must be absolute)
  - content (required, string): The content to write to the file

  Notes:
  - Overwrites existing files
  - Must Read existing files first before writing
  - Prefer editing existing files over creating new ones

  ---
  9. NotebookEdit

  Description: Replaces contents of a specific cell in a Jupyter notebook (.ipynb file).

  Parameters:
  - notebook_path (required, string): Absolute path to the Jupyter notebook
  - new_source (required, string): The new source for the cell
  - cell_id (optional, string): ID of the cell to edit
  - cell_type (optional, enum): code or markdown
  - edit_mode (optional, enum): replace (default), insert, or delete

  ---
  10. WebFetch

  Description: Fetches content from a URL and processes it using an AI model.

  Parameters:
  - url (required, string, format: uri): The URL to fetch content from
  - prompt (required, string): The prompt to run on the fetched content

  Notes:
  - HTTP upgraded to HTTPS automatically
  - Has a 15-minute cache
  - Returns redirect info if redirect occurs to different host

  ---
  11. WebSearch

  Description: Search the web and use results to inform responses.

  Parameters:
  - query (required, string, minLength: 2): The search query to use
  - allowed_domains (optional, string[]): Only include results from these domains
  - blocked_domains (optional, string[]): Never include results from these domains

  Notes: Must include "Sources:" section with URLs in response after using.

  ---
  12. TodoWrite

  Description: Create and manage a structured task list for the current coding session.

  Parameters:
  - todos (required, array): The updated todo list
    - Each item has:
        - content (required, string): Imperative form (e.g., "Run tests")
      - activeForm (required, string): Present continuous form (e.g., "Running tests")
      - status (required, enum): pending, in_progress, or completed

  Notes: Only one task should be in_progress at a time.

  ---
  13. AskUserQuestion

  Description: Ask the user questions during execution to gather preferences, clarify instructions, or get decisions.

  Parameters:
  - questions (required, array, 1-4 items): Questions to ask
    - Each question has:
        - question (required, string): The complete question to ask
      - header (required, string): Short label (max 12 chars) like "Auth method"
      - options (required, array, 2-4 items): Available choices
            - label (required, string): Display text (1-5 words)
        - description (required, string): Explanation of the option
      - multiSelect (required, boolean): Allow multiple selections

  ---
  14. EnterPlanMode

  Description: Transitions into plan mode to design implementation approach for user approval before writing code.

  Parameters: None (empty object)

  Notes: Use for non-trivial tasks with multiple valid approaches or architectural decisions.

  ---
  15. ExitPlanMode

  Description: Signal that you've finished writing your plan and are ready for user approval.

  Parameters:
  - launchSwarm (optional, boolean): Whether to launch a swarm to implement the plan
  - teammateCount (optional, number): Number of teammates to spawn in the swarm

  ---
  16. KillShell

  Description: Kills a running background bash shell by its ID.

  Parameters:
  - shell_id (required, string): The ID of the background shell to kill

  ---
  17. Skill

  Description: Execute a skill within the main conversation.

  Parameters:
  - skill (required, string): The skill name (no arguments)

  Available Skills:
  - dev-workflow:test-driven-development
  - dev-workflow:pragmatic-architecture
  - dev-workflow:testing-anti-patterns
  - dev-workflow:systematic-debugging
  - dev-workflow:finishing-a-development-branch
  - dev-workflow:root-cause-tracing
  - dev-workflow:getting-started
  - dev-workflow:condition-based-waiting
  - dev-workflow:receiving-code-review
  - dev-workflow:verification-before-completion
  - dev-workflow:defense-in-depth

  ---
  18. SlashCommand

  Description: Execute a slash command within the main conversation.

  Parameters:
  - command (required, string): The slash command to execute with arguments (e.g., /review-pr 123)

  Available Commands:
  - /dev-workflow:workflow-status
  - /dev-workflow:brainstorm [topic or @design-doc.md]

  ---
  19. mcp__context7__resolve-library-id

  Description: Resolves a package/product name to a Context7-compatible library ID.

  Parameters:
  - libraryName (required, string): Library name to search for

  Notes: Must call this before get-library-docs to obtain a valid library ID.

  ---
  20. mcp__context7__get-library-docs

  Description: Fetches up-to-date documentation for a library.

  Parameters:
  - context7CompatibleLibraryID (required, string): Exact library ID (e.g., /mongodb/docs, /vercel/next.js)
  - topic (optional, string): Topic to focus on (e.g., hooks, routing)
  - mode (optional, enum, default: code): code for API references, info for conceptual guides
  - page (optional, integer, 1-10, default: 1): Page number for pagination