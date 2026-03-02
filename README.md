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
  | /code:implement           |  <-- code-et plugin
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
  | code-et plugin (execution engine)            |
  | - /code:implement  (orchestrator+subagents)  |
  | - /code:setup      (stack detection)         |
  | - /code:pr         (GitHub PRs)              |
  | - /code:cleanup    (CLAUDE.md organization)  |
  | - /code:bun-init   (project scaffolding)     |
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
claude plugin install rust-analyzer-lsp --marketplace claude-plugins-official
claude plugin install pyright-lsp --marketplace claude-plugins-official
claude plugin install frontend-design --marketplace claude-plugins-official
```

**code-et plugin** (custom marketplace — add first, then install):

```bash
claude marketplace add NOGIT007/code-et
claude plugin install coding-plugin --marketplace code-et
```

## Skills Reference

### code-et plugin

| Skill             | Description                                                                                                                   |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `/code:setup`     | Detects project stack and generates `.claude/settings.json` with permissions                                                  |
| `/code:implement` | Picks up native tasks, spawns orchestrator + parallel implementers in worktrees. Each runs verification, auto-commits on pass |
| `/code:pr`        | Creates GitHub PR with auto-generated description from branch commits                                                         |
| `/code:cleanup`   | Refactors CLAUDE.md — keeps root lean, moves details to `.claude/rules/`                                                      |
| `/code:bun-init`  | Scaffolds new Bun + Next.js + Shadcn/UI project with Docker and GCP Cloud Run setup                                           |

### Official plugins

| Skill              | Plugin          | Description                                                                                                                                                     |
| ------------------ | --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/commit`          | commit-commands | Creates a git commit with auto-generated message                                                                                                                |
| `/commit-push-pr`  | commit-commands | Creates branch, commits, pushes, and opens a PR in one step                                                                                                     |
| `/clean_gone`      | commit-commands | Removes local branches marked as `[gone]` (deleted on remote), including associated worktrees                                                                   |
| `/code-review`     | code-review     | Multi-agent PR review — 5 parallel agents check CLAUDE.md compliance, bugs, git history, past PR comments, and code comments. Scores each finding by confidence |
| `/frontend-design` | frontend-design | Creates distinctive, production-grade UI components with bold design direction. Avoids generic AI aesthetics                                                    |
| `/simplify`        | code-review     | Reviews changed code for reuse, quality, and efficiency, then fixes issues found                                                                                |

### Typical workflow

```
1. /clean_gone
   → Clean up stale branches and worktrees from previous work

2. Plan Mode (Shift+Tab)
   → Explore codebase with LSP, design approach

3. TaskCreate
   → Create tasks with metadata.verification and metadata.files
   → Set blockedBy dependencies

4. Exit plan mode (approve)

5. /code:implement
   → Orchestrator spawns implementers in worktrees
   → Each runs tests, auto-commits on pass

6. /commit-push-pr
   → Commits remaining changes, pushes, opens PR

7. /code-review
   → Colleague reviews with multi-agent analysis
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

1. **Clean** — Run `/clean_gone` to remove stale branches and worktrees
2. **Plan** — Use Plan Mode (Shift+Tab) to explore and design
3. **Tasks** — Create tasks with `TaskCreate` including metadata
4. **Implement** — Run `/code:implement` to execute tasks with subagents
5. **PR** — Run `/commit-push-pr` to commit, push, and create PR
6. **Review** — Colleague runs `/code-review` on the PR
7. **Merge + Pull** — Merge on GitHub, `git pull origin main`
