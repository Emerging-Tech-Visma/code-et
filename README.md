# code-et

Team development workflow powered by Claude Code + plugins.

Bun + Next.js project using task-driven development — no GitHub issues, pure Claude Code task workflow.

## Workflow

```
+------------------------------------------------------------------+
|                    CLAUDE CODE + PLUGINS FLOW                     |
+------------------------------------------------------------------+

  YOU (Developer A)                          COLLEAGUE (Developer B)
  ================                          ======================

  1. PLAN
  +---------------------------+
  | Shift+Tab (Plan Mode)     |  <-- Claude Code native
  | - Explore codebase        |
  | - LSP: go-to-def, refs    |
  | - Design approach         |
  +---------------------------+
              |
  2. CREATE TASKS
  +---------------------------+
  | TaskCreate (native)       |  <-- Claude Code native
  | - metadata.verification   |
  | - metadata.files          |
  | - blockedBy dependencies  |
  +---------------------------+
              |
  3. IMPLEMENT
  +---------------------------+
  | /code:implement           |  <-- Innovation Basement
  |                           |
  |   Orchestrator (bg)       |
  |   +-- Implementer 1 (wt) |
  |   +-- Implementer 2 (wt) |
  |   +-- Implementer N (wt) |
  |                           |
  |   Each implementer:       |
  |   - Hard verification     |
  |   - Auto-commit on pass   |
  |                           |
  |   /simplify (auto, end)   |  <-- Official plugin
  +---------------------------+
              |
  4. PR
  +---------------------------+
  | /commit-push-pr           |  <-- commit-commands plugin
  | - Commits remaining       |     5. REVIEW
  | - Pushes branch           |     +--------------------+
  | - Creates PR on GitHub    | --> | /code-review       | <-- Official
  +---------------------------+     | - Multi-agent      |
                                    | - Approve/request  |
                                    +--------------------+
                                             |
  6. PULL                            Merge on GitHub
  +---------------------------+              |
  | git pull origin main      | <------------+
  +---------------------------+

  wt = git worktree    bg = background agent
```

### Git Branch Flow

```
  main ---------.---------------------------*--- (merged, pull)
                 \                         /
                  feature/my-feature -*--*--PR
                                      ^  ^
                                    task commits
```

### Plugin Stack

```
  +----------------------------------------------+
  | Claude Code (native)                         |
  | - Plan Mode, TaskCreate, gh CLI, worktrees   |
  +----------------------------------------------+
  | Official Plugins                             |
  | - commit-commands  (commit, push, PR)        |
  | - code-review      (PR review)               |
  | - code-simplifier  (/simplify)               |
  | - typescript-lsp   (LSP navigation)          |
  +----------------------------------------------+
  | Innovation Basement (execution engine)       |
  | - /code:implement  (orchestrator+subagents)  |
  |   No issue refs — pure task-based            |
  | - /code:setup      (stack detection)         |
  | - /code:cleanup    (CLAUDE.md organization)  |
  +----------------------------------------------+
```

## Prerequisites

- **Claude Code** — `npm install -g @anthropic-ai/claude-code`
- **Bun** — `curl -fsSL https://bun.sh/install | bash`
- **GitHub CLI (`gh`)** — used by plugins for PRs, issues, and code review ([install](https://cli.github.com/))

## Getting Started

```bash
git clone https://github.com/Emerging-Tech-Visma/code-et.git
cd code-et
bun install
bun dev
```

## Plugin Installation

**Official plugins (Claude Code):**

```bash
claude plugin install commit-commands --marketplace claude-plugins-official
claude plugin install code-review --marketplace claude-plugins-official
claude plugin install typescript-lsp --marketplace claude-plugins-official
claude plugin install frontend-design --marketplace claude-plugins-official
```

**code-et plugin** (custom marketplace — add first, then install):

```bash
claude marketplace add NOGIT007/innovation-basement
claude plugin install coding-plugin --marketplace innovation-basement
```

## Project Setup

After plugins are installed, run inside the project:

```bash
claude
# then inside Claude Code:
/code:setup
```

This auto-detects the stack and configures `.claude/settings.json` permissions.

## Recommended Hooks

Auto-format on file writes with Prettier — add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "npx prettier --write \"$CLAUDE_TOOL_INPUT_FILE_PATH\""
          }
        ]
      }
    ]
  }
}
```

## Development

1. **Plan** — Use Plan Mode (Shift+Tab) to explore and design
2. **Tasks** — Create tasks with `TaskCreate` including metadata
3. **Implement** — Run `/code:implement` to execute tasks with subagents
4. **PR** — Run `/commit-push-pr` to commit, push, and create PR
5. **Review** — Colleague runs `/code-review` on the PR
6. **Merge + Pull** — Merge on GitHub, `git pull origin main`
