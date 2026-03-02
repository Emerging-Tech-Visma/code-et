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
  +-----------------------------------+
  | /code:implement                   |  <-- code-et plugin
  |                                   |
  | Subagent mode (default):          |
  |   Orchestrator (bg)               |
  |   +-- Implementer 1 (wt)         |
  |   +-- Implementer 2 (wt)         |
  |   +-- Implementer N (wt)         |
  |                                   |
  | Team mode (--team):               |
  |   Lead → Teammate 1..N            |
  |   Each claims + implements tasks  |
  |                                   |
  |   Each implementer/teammate:      |
  |   - Hard verification             |
  |   - Auto-commit on pass           |
  |                                   |
  |   /simplify (auto, end)           |  <-- Official plugin
  +-----------------------------------+
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

## Building a Plugin from Scratch

This section documents how the code-et plugin was built — use it as a guide for creating your own Claude Code marketplace plugin.

### Step 1: Repository Structure

A marketplace repo has two levels:

- **Root** `.claude-plugin/marketplace.json` — declares which plugins exist and where to find them
- **Subdirectory** (e.g. `coding-plugin/`) — contains the actual plugin with its own `.claude-plugin/plugin.json`

```
my-repo/                              ← GitHub repo root
├── .claude-plugin/
│   └── marketplace.json              ← marketplace manifest (points to subdirs)
├── coding-plugin/                    ← plugin subdirectory
│   ├── .claude-plugin/
│   │   ├── plugin.json               ← plugin identity (name, version)
│   │   └── settings.json             ← permissions, env vars, spinner tips
│   ├── CLAUDE.md                     ← instructions loaded when plugin is active
│   ├── agents/                       ← subagent definitions
│   │   ├── orchestrator.md
│   │   └── implementer.md
│   ├── commands/                     ← slash commands (skills)
│   │   ├── implement.md
│   │   ├── setup.md
│   │   └── cleanup.md
│   ├── hooks/
│   │   └── hooks.json                ← lifecycle hooks
│   └── scripts/                      ← shell scripts invoked by hooks
│       ├── verify-gate.sh
│       └── run-tests.sh
├── README.md                         ← repo docs (not part of plugin)
└── package.json                      ← repo-level config (not part of plugin)
```

> **Key rule:** `marketplace.json` uses `"source": "./coding-plugin"` — the source must point to a subdirectory, never `"."`.

### Step 2: Create the Directory Structure

```bash
# From your repo root
mkdir -p coding-plugin/.claude-plugin
mkdir -p coding-plugin/{agents,commands,hooks,scripts}
mkdir -p .claude-plugin
```

### Step 3: Marketplace Manifest

Create `.claude-plugin/marketplace.json` at the **repo root**:

```json
{
  "name": "code-et",
  "owner": {
    "name": "Your Name"
  },
  "metadata": {
    "description": "Task-driven coding workflow with parallel agents in worktrees",
    "version": "1.0.0"
  },
  "plugins": [
    {
      "name": "code",
      "source": "./coding-plugin",
      "description": "Task-driven coding workflow with native Task tools."
    }
  ]
}
```

- `name` — marketplace name (matches the repo)
- `plugins[].name` — becomes the skill prefix (`/code:*`)
- `plugins[].source` — relative path to the plugin subdirectory

### Step 4: Plugin Identity

Create `coding-plugin/.claude-plugin/plugin.json`:

```json
{
  "name": "code",
  "version": "1.0.0",
  "description": "Task-driven coding workflow with native Task tools.",
  "author": {
    "name": "Your Name"
  },
  "license": "MIT",
  "keywords": ["coding", "workflow", "agents"]
}
```

The `name` field here **must match** the `plugins[].name` in `marketplace.json`. This determines the skill prefix — `"code"` means `/code:implement`, `/code:setup`, etc.

### Step 5: Plugin Settings

Create `coding-plugin/.claude-plugin/settings.json`:

```json
{
  "plansDirectory": "plans",
  "env": {
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "70"
  },
  "permissions": {
    "allow": ["Bash(git:*)", "Bash(gh:*)", "Bash"]
  }
}
```

### Step 6: Add Commands (Skills)

Each `.md` file in `coding-plugin/commands/` becomes a skill callable as `/code:<filename>`.

| File           | Skill             |
| -------------- | ----------------- |
| `implement.md` | `/code:implement` |
| `setup.md`     | `/code:setup`     |
| `cleanup.md`   | `/code:cleanup`   |
| `pr.md`        | `/code:pr`        |
| `bun-init.md`  | `/code:bun-init`  |

Commands are markdown files with instructions that Claude follows when the skill is invoked.

### Step 7: Add Agents

Each `.md` file in `coding-plugin/agents/` becomes a subagent type callable as `code:<filename>`.

| File              | Subagent type       |
| ----------------- | ------------------- |
| `orchestrator.md` | `code:orchestrator` |
| `implementer.md`  | `code:implementer`  |

Agents are spawned via the `Agent` tool with `subagent_type: "code:orchestrator"`.

### Step 8: Add Hooks and Scripts

`coding-plugin/hooks/hooks.json` defines lifecycle hooks. Scripts go in `coding-plugin/scripts/` and are referenced via `${CLAUDE_PLUGIN_ROOT}/scripts/`:

```json
{
  "hooks": {
    "SubagentStop": [
      {
        "matcher": "code:implementer",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/verify-gate.sh"
          }
        ]
      }
    ]
  }
}
```

### Step 9: Add Plugin CLAUDE.md

`coding-plugin/CLAUDE.md` contains instructions loaded when the plugin is active. This is where you document workflow rules, conventions, and project standards.

### Step 10: Publish and Install

```bash
# In Claude Code — commit, push branch, and create PR
/commit-push-pr

# After PR is merged — add marketplace and install
/plugin marketplace add YourOrg/your-repo
/plugin install code@code-et
```

After installation, all commands appear as skills (e.g. `/code:implement`), agents are available as subagent types, and hooks run automatically.

To update after pushing changes:

```
/plugin  →  Marketplaces  →  code-et  →  Update
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

```
/plugin install commit-commands@claude-plugins-official
/plugin install code-review@claude-plugins-official
/plugin install typescript-lsp@claude-plugins-official
/plugin install rust-analyzer-lsp@claude-plugins-official
/plugin install pyright-lsp@claude-plugins-official
/plugin install frontend-design@claude-plugins-official
```

**code-et plugin** (add marketplace, then install):

```
/plugin marketplace add Emerging-Tech-Visma/code-et
/plugin install code@code-et
```

## Skills Reference

### code-et plugin

| Skill             | Description                                                                                                                                                     |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/code:setup`     | Detects project stack and generates `.claude/settings.json` with permissions                                                                                    |
| `/code:implement` | Picks up native tasks. Subagent mode (default): orchestrator + parallel implementers in worktrees. Team mode (`--team`): Agent Swarm with distributed teammates |
| `/code:pr`        | Creates GitHub PR with auto-generated description from branch commits                                                                                           |
| `/code:cleanup`   | Refactors CLAUDE.md — keeps root lean, moves details to `.claude/rules/`                                                                                        |
| `/code:bun-init`  | Scaffolds new Bun + Next.js + Shadcn/UI project with Docker and GCP Cloud Run setup                                                                             |

### Official plugins

| Skill              | Plugin          | Description                                                                                                                                                     |
| ------------------ | --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/commit`          | commit-commands | Creates a git commit with auto-generated message                                                                                                                |
| `/commit-push-pr`  | commit-commands | Creates branch, commits, pushes, and opens a PR in one step                                                                                                     |
| `/clean_gone`      | commit-commands | Removes local branches marked as `[gone]` (deleted on remote), including associated worktrees                                                                   |
| `/code-review`     | code-review     | Multi-agent PR review — 5 parallel agents check CLAUDE.md compliance, bugs, git history, past PR comments, and code comments. Scores each finding by confidence |
| `/frontend-design` | frontend-design | Creates distinctive, production-grade UI components with bold design direction. Avoids generic AI aesthetics                                                    |
| `/simplify`        | code-review     | Reviews changed code for reuse, quality, and efficiency, then fixes issues found                                                                                |

## Project Setup

After plugins are installed, run inside the project:

```bash
claude
# then inside Claude Code:
/code:setup
```

This auto-detects the stack and configures `.claude/settings.json` permissions.

## Configuration

### Execution Modes

`/code:implement` runs in subagent mode by default (orchestrator + parallel implementers in worktrees). Pass `--team` to use Agent Swarm team mode instead.

### Environment Variables

| Variable                               | Where                          | Purpose                              |
| -------------------------------------- | ------------------------------ | ------------------------------------ |
| `CLAUDE_CODE_TASK_LIST_ID`             | `.claude/settings.json`        | Scoped task list name                |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`      | `.claude-plugin/settings.json` | Auto-compact threshold (default: 70) |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | `.claude/settings.json`        | Set to `1` to enable Agent Swarm     |

To enable team mode, add to `.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

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
